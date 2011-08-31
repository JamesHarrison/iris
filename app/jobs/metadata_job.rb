require 'iconv'
require 'fileutils'
# MetadataJob is the first thing that comes into contact with incoming audio.
# Its job is to simply read all the data it can out of the metadata in whatever encapsulation the data arrives in.
class ExternalMetadataError < Exception; end
class MetadataJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "MetadataJob: Started")
    # When nginx handles the upload, it strips the extension. We have to put that back so we can use our tools on it.
    # We do this by making a symbolic link from the -filename- to the uploaded -path-. We first remove it if one exists already.
    File.unlink(Settings.path_to_uploads+"/"+u.filename) rescue nil
    FileUtils.symlink(u.path, Settings.path_to_uploads+"/"+u.filename)
    u.atl("INFO", "MetadataJob: Creating symlink #{Settings.path_to_uploads+"/"+u.filename} -> #{u.path}")
    # Try and pull out the basics from the file.
    begin
      # Technical data we go to ffmpeg for, since that's what we'll be using to work with this later
      info = FFMpeg::AVFormatContext.new(Settings.path_to_uploads+"/"+u.filename)
      u.bitrate = (info.bit_rate/1000) # kilobits per second
      u.length = (info.duration/1000) # gets us milliseconds
      u.format = info.codec_contexts.first.name
      u.long_format = info.codec_contexts.first.long_name
      u.channels = info.codec_contexts.first.channels
      u.sample_rate = info.codec_contexts.first.sample_rate
      u.save!
    rescue Exception => e
      # Something went wrong while trying to read the file's metadata. Again, could try ffprobe or exiftool as a last resort.
      u.atl("WARN", "MetadataJob: Unable to read technical metadata from file (#{e.inspect})")
    end
    begin
      # Non-technical metadata (artist, title, album etc) we go to exiftool for, because it rocks. Seriously.
      exif_stdout = ''
      IO.popen(['exiftool', (Settings.path_to_uploads+"/"+u.filename)]){|io| exif_stdout = io.read }
      conv = Iconv.new("US-ASCII//TRANSLIT//IGNORE", "UTF8");
      # motherofgod.jpg (This just takes the output of exiftool, cleans it up somewhat, uses iconv to convert any special utf-8 characters to ASCII (ignoring anything it can't transliterate) and spits out a hash
      exif = exif_stdout.gsub("  ", "").split("\n").map{|l|l.split(":")}.map{|kv|[kv[0].strip,kv[1].strip]}.inject({}){|r,e|r[e[0]]=(conv.iconv(e[1]) rescue e[1]);r}
      u.atl("INFO", "MetadataJob: EXIFtool data #{exif.inspect}")
      u.title = exif["Title"] rescue nil
      u.artist = exif["Artist"] rescue nil
      u.album = exif["Album"] rescue nil
      u.year = exif["Year"] rescue nil
      u.genre = exif["Genre"] rescue nil
      u.copyright = exif["Copyright"] rescue nil
      u.composer = exif["Composer"] rescue nil
      u.save!
    rescue Exception => e
      u.atl("ERROR", "MetadataJob: Unable to read non-technical metadata from file (#{e.inspect})")
    end
    begin
      # If we have metadata now, let's move on.
      if u.title and u.artist
        u.atl("INFO", "MetadataJob: Beginning metadata lookups")
        # Match these to a MusicBrainz artist
        brainz = MusicBrainz::Client.new()
        mbam = MusicbrainzAutomatcher.new({:musicbrainz_host => 'musicbrainz.org', :network_timeout => 1, :network_retries => 2})
        a_id = mbam.match_artist(u.artist, u.title)
        # If this is actually a multi-artist collaboration we should split this with a regexp.
        mb_artist = nil
        mar = Regexp.new(/(.+) (&|feat.?|and|ft.?|vs.?|featuring|\+)\s(.*)/i)
        if mar.match(u.artist)
          # We're now in a scenario whereby we have two artists involved.
          # FIXME: Support comma seperated artists
          # We assume good taggers will put the main artist first and select that artist. We don't fiddle with the stored artist. Just for MB.
          # We need to get a good lookup on MB so we can get track info accurately. Primary artists are the only ones MB indexes by.
          u.atl("WARN", "MetadataJob: Assuming composite artist string, will search for artist #{mar.match(u.artist)[1]}")
          mb_artist = mar.match(u.artist)[1]
        end
        # Intelligent automatcher borked. We'll assume the highest scoring one is probably right because we're optimistic unlike MBAM.
        if !a_id
          u.atl("WARN", "MetadataJob: Automatching failed, picking the best scoring artist on simple search")
          possible_artists = brainz.artist(nil, :query=>(mb_artist ? mb_artist : u.artist)).artist_list
          if possible_artists.length >= 1
            a_id = possible_artists.artist[0].id rescue nil
            a_id = possible_artists.artist.id rescue nil if !a_id
          end
        end
        raise(ExternalMetadataError, "Could not find artist #{u.artist} in MusicBrainz") if !a_id
        u.atl("INFO", "MetadataJob: Got artist #{a_id}")
        u.musicbrainz_artist_id = a_id
        t_id = nil
        possible_tracks = brainz.track(nil, :title=>u.title, :artistid=>a_id).track_list
        if possible_tracks.length >= 1 and possible_tracks.track
          t_id = possible_tracks.track[0].id rescue nil if !t_id
          t_id = possible_tracks.track.id rescue nil if !t_id
        end
        raise(ExternalMetadataError, "Could not find track #{u.title} in MusicBrainz") if !t_id
        t = brainz.track(t_id, :inc=>'isrcs+releases+artist-rels')
        u.atl("INFO", "MetadataJob: Got track #{t_id}")
        u.musicbrainz_track_id = t_id
        # If we have more than one ISRC, pick the first one - we're not picky, this is all guesswork.
        if (t.track.isrc_list.length rescue 0) >= 1
          u.isrc = t.track.isrc_list.isrc[0].id rescue nil if !u.isrc
          u.isrc = t.track.isrc_list.isrc.id rescue nil if !u.isrc
        end
        u.atl("INFO", "MetadataJob: ISRC: #{u.isrc}")
        u.composer = t.track.relation_list.relation.to_a.detect{|rt|rt.type == "Composer"}.artist.name rescue nil if !u.composer
        u.atl("INFO", "MetadataJob: Composer: #{u.composer}")
        u.save
        r_id = nil
        # If we have a release for this recording, pick it (any will do) and get the label and tags
        # TODO: Use album metadata where possible
        if (t.track.release_list.length rescue 0) >= 1 
          r_id = t.track.release_list.release[0].id rescue nil if !r_id
          r_id = t.track.release_list.release.id rescue nil if !r_id
        end
        if r_id
          u.atl("INFO", "MetadataJob: Got release #{r_id}")
          r = brainz.release(r_id, :inc=>'labels+label-rels+release-rels+tags+counts+discs+release-events')
          if (r.release.release_event_list.length rescue 0) >= 1
            u.publisher = r.release.release_event_list.event[0].label.name rescue nil if !u.publisher
            u.publisher = r.release.release_event_list.event.label.name rescue nil if !u.publisher
          end
          u.atl("INFO", "MetadataJob: Publisher: #{u.publisher}")
          u.genre = r.release.tag_list.to_a[0][1].join(", ") rescue nil if !u.genre
          u.atl("INFO", "MetadataJob: Genre: #{u.genre}")
          u.save
        else
          u.atl("WARN", "MetadataJob: Could not find release in MusicBrainz")
        end
      else
        u.atl("WARN", "MetadataJob: No metadata lookup, no data available")
      end
    rescue ExternalMetadataError => e
      u.atl("WARN", "MetadataJob: Error while fetching metadata from MusicBrainz, giving up: #{e.inspect}")
    rescue MusicBrainz::Webservice::ConnectionError => e
      u.atl("WARN", "MetadataJob: Connection error while fetching metadata from MusicBrainz, skipping MB lookup for this track: #{e.inspect}")
    end
    u.atl("INFO", "MetadataJob: Finished")
    u.got_metadata!
  end
  def failure;u = Upload.find(self.upload_id);u.mark_failed; end
end
