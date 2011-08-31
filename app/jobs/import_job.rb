require 'fileutils'
class ExportError < Exception; end
class ImportJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "ImportJob: Started")
    in_path = Settings.path_to_import+"/"+u.filename+".normalized.wav"
    out_path = ''
    begin
      # Rivendell rdimport mode
      if Settings.rivendell_import_enabled == true
        u.atl("INFO", "ImportJob: Importing to Rivendell")
        # Build a filename- rdimport takes metadata in the filename. See metadata pattern below.
        filename = [u.artist,u.title,(u.album or '' rescue ''),((u.publisher+" - ISRC "+u.isrc) or '' rescue ''),(u.copyright or '' rescue ''),(u.composer or '' rescue '')].join("__-__-__")+".wav"
        # Let's copy this to our import path
        out_path = Settings.path_to_import+"/"+filename
        FileUtils.mv(in_path, out_path)
        raise(ExportError, "WAV copy from #{in_path} was not performed successfully") unless File.exists?(out_path)
        log = ''
        IO.popen(['rdimport', 
          '--metadata-pattern=%a__-__-__%t__-__-__%l__-__-__%p__-__-__%b__-__-__%m.wav', 
          "--autotrim-level=#{Settings.rivendell_import_autotrim_level}",
          "--segue-level=#{Settings.rivendell_import_segue_level}",
          "--segue-length=#{Settings.rivendell_import_segue_length}",
          Settings.rivendell_import_group,
          out_path
        ]){|io|log=io.read}
        # We're done with the file now.
        File.delete(out_path)
        # TODO: Set cart number automatically in the IRIS side database
        # FIXME: Check if RD import worked, error if not
        u.atl("INFO", "ImportJob: Imported to Rivendell successfully. Full log from rdimport follows.")
        u.atl("INFO", "ImportJob: #{log}")
        u.imported_okay
      end
      # File import mode. Which exports a file. Okay, bad naming scheme.
      if Settings.file_import_enabled == true
        filename = "#{u.id}---#{u.artist}--#{u.title}" # set extension below
        u.atl("INFO", "ImportJob: Importing to filesystem")
        out_path = Settings.path_to_import+"/"+filename
        if Settings.file_import_format == 'mp3'
          u.atl("INFO", "ImportJob: MP3 format selected")
          out_path = out_path+".mp3"
          export_mp3(u, in_path, out_path)
          u.imported_okay
        elsif Settings.file_import_format == 'bwf'
          u.atl("INFO", "ImportJob: Broadcast Wave Format selected (linear PCM), copying")
          out_path = out_path+".wav"
          FileUtils.mv(in_path, out_path)
          raise(ExportError, "WAV move from #{in_path} was not performed successfully") unless File.exists?(out_path)
          u.atl("INFO", "ImportJob: BWF filesystem write complete, tagging")
          log = ''
          IO.popen(['bwfmetaedit', 
            "--Description=\"#{u.title}\"",
            "--Originator=\"#{u.artist}\"",
            "--OriginatorReference=\"IRISID-#{u.id}-ISRC-#{u.isrc}\"",
            out_path]){|io|log=io.read}
          u.atl("INFO", "ImportJob: BWF chunks written")
          # FIXME: BWF chunk writing needs validating or at least need to check bwfmetaedit didn't have issues
          # raise(ExportError, "WAV copy from #{in_path} was not performed successfully") unless File.exists?(out_path) 
          u.imported_okay
        elsif Settings.file_import_format == 'wav'
          u.atl("INFO", "ImportJob: Untagged linear PCM WAV format selected, copying")
          out_path = out_path+".wav"
          FileUtils.mv(in_path, out_path)
          raise(ExportError, "WAV move from #{in_path} was not performed successfully") unless File.exists?(out_path)
          u.atl("INFO", "ImportJob: WAV filesystem write complete")
          u.imported_okay
        elsif Settings.file_import_format == 'flac'
          u.atl("INFO", "ImportJob: FLAC format selected, encoding")
          out_path = out_path+".flac"
          flac_out = ''
          IO.popen(['flac', '--best', '--tag=TITLE='+u.title, '--tag=ARTIST='+u.artist, '--tag=ALBUM='+u.album, in_path, '-o', out_path]){|io|flac_out = io.read}
          raise(ExportError, "FLAC encoder didn't write anything") unless File.exists?(out_path)
          u.imported_okay
        elsif Settings.file_import_format == 'aac'
          u.atl("INFO", "ImportJob: AAC format selected, encoding")
          out_path = out_path+".m4a"
          faac_out = ''
          IO.popen(['faac', '-q', '150', '--title='+u.title, '--artist='+u.artist, '--album='+u.album, '--writer='+u.composer, '--year='+u.year.to_s, in_path, '-o', out_path]){|io|faac_out = io.read}
          raise(ExportError, "AAC encoder didn't write anything") unless File.exists?(out_path)
          u.imported_okay
        else
          u.atl("ERROR", "ImportJob: Unknown format specified- not doing anything! See config/settings.yml for valid options")
          u.import_failure
        end
      end
      # Now we've done all the importing we want to do, so let's nuke the old stuff
      u.atl("INFO", "ImportJob: Wrote to #{out_path}")
    rescue ExportError => e
      u.atl("ERROR", "ImportJob: ExportError thrown, issue writing or encoding file. Ensure appropriate encoder is installed and paths are set correctly and writeable.")
      u.atl("ERROR", "ImportJob: Error details: #{e.inspect} #{e.to_s}")
    rescue Exception => e
      u.atl("ERROR", "ImportJob: Error occured while trying to export content to the filesystem or import to a playout system: #{e.inspect} #{e.to_s}")
    end
    # Now we can clean up all those messy files that NormalizeJob left lying around... and then some.
    [
      (Settings.path_to_import+"/"+u.filename+".normalized.wav"),
      (Settings.path_to_import+"/"+u.filename+".wav"),
      (Settings.path_to_import+"/"+u.filename+".eca.wav"),
      (u.path),
    ].each do |path|
      File.delete(path) rescue nil
    end
    File.unlink(Settings.path_to_uploads+"/"+u.filename) rescue nil
    u.atl("INFO", "ImportJob: Cleaned up temporary content")
    u.atl("INFO", "ImportJob: Finished")
  end
  # This chunk of thinking is shared between Myriad and file import modes.
  def export_mp3(u,in_path,out_path)
    log = ''
    IO.popen(['lame', '--preset', 'insane', '--noreplaygain', '--strictly-enforce-ISO', in_path, out_path]){|io|log=io.read}
    raise(ExportError, "MP3 encoding to #{out_path} was not performed successfully") unless File.exists?(out_path)
    u.atl("INFO", "ImportJob: MP3 written to #{out_path}")
    taglog = ''
    IO.popen(['id3tag', '--song='+u.title, '--artist='+u.artist, '--album='+u.album, '--comment='+u.composer, '--year='+u.year.to_s, "--comment=IRIS Upload #{u.id}", out_path]){|io|taglog = io.read}
    u.atl("INFO", "ImportJob: ID3 tags written")
  end
  def failure;u = Upload.find(self.upload_id);u.mark_failed; end
end
