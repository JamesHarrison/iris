# FilterJob handles filtering incoming files based on their incoming quality, format, and on lyrics if possible.
# Metadata for this job is extracted and stored against uploads by the Metadata job
# Anything that fails filtering is placed in a queue to be reviewed.
# Deduplication is also done here.
require 'yajl'
require 'open-uri'
class FilterJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "FilterJob: Started")
    quality_okay = false
    lyrics_okay = false
    # Scrap the file if it's m4p.
    if u.filename.include?(".m4p")
      u.atl("ERROR", "FilterJob: File is DRM-protected, cannot import")
      u.fail_filtering_drm
    else
      # First things first: Do we have quality metadata?
      if u.bitrate and u.sample_rate
        if u.bitrate < Settings.minimum_bitrate # Too low-quality, bitrate-wise?
          u.atl("ERROR", "FilterJob: Bitrate (#{u.bitrate}) is below threshold of #{Settings.minimum_bitrate}kbps. Flagging for review.")
          u.fail_filtering
        else
          u.atl("INFO", "FilterJob: Bitrate (#{u.bitrate}) is above threshold of #{Settings.minimum_bitrate}kbps, passed")
          if u.sample_rate < Settings.minimum_sample_rate # Sample rate too low?
            u.atl("ERROR", "FilterJob: Sample rate (#{u.sample_rate}) is below threshold of #{Settings.minimum_sample_rate}Hz. Flagging for review.")
            u.fail_filtering
          else
            u.atl("INFO", "FilterJob: Sample rate (#{u.sample_rate}) is above threshold of #{Settings.minimum_sample_rate}Hz, passed")
            quality_okay = true # We're good on both raw technical quality counts.
          end
        end
      else
        u.atl("ERROR", "FilterJob: No bitrate stored. Unable to enforce quality. Flagging for review.")
      end
    end
    
    lyrics_okay = true
    if Settings.musixmatch_api_key and Settings.musixmatch_api_key.length == 32
      if (u.filename.downcase.include?("radio edit") or u.title.downcase.include?("radio edit"))
        u.atl("WARN", "FilterJob: Lyric filtering BYPASSED - Radio edit")
      else
        u.atl("INFO", "FilterJob: Lyric filtering started, attempting to retrieve lyrics")
        parser = Yajl::Parser.new
        json = open("http://api.musixmatch.com/ws/1.1/track.lyrics.get?track_mbid=#{u.musicbrainz_track_id}&format=json&apikey=#{Settings.musixmatch_api_key}").read()
        data = parser.parse(json)
        code = data['message']['header']['status_code'].to_i
        if code == 200
          lyrics = data['message']['body']['lyrics']['lyrics_body']
          u.lyrics = lyrics
          u.save!
          lyrics = lyrics.downcase
          # We now have the lyrics in a string.
          for word in Settings.bad_words
            if lyrics.include?(word)
              u.atl("ERROR", "FilterJob: Lyric filtering flagged song for review based on badword #{word}")
              lyrics_okay = false
              u.fail_filtering
            end
          end
          if lyrics_okay
            u.atl("INFO", "FilterJob: Lyric filtering passed, no bad words detected")
          end
        else
          u.atl("WARN", "FilterJob: Lyric filtering failed, got code #{code} - response #{data.inspect}")
        end
      end
    else
      u.atl("WARN", "FilterJob: MusixMatch Lyrics API key not specified, skipping lyric filtering")
    end

    u.atl("INFO", "FilterJob: Finished")
    if quality_okay and lyrics_okay
      u.pass_filtering
    end
  end
  def failure;u = Upload.find(self.upload_id);u.mark_failed; end
end
