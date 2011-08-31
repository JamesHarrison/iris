require 'fileutils'
class ImportJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "ImportJob: Started")
    in_path = Settings.path_to_import+"/"+u.filename+".normalized.wav"
    # Rivendell mode.
    if Settings.rivendell_import_enabled == true
      u.atl("INFO", "ImportJob: Importing to Rivendell")
      # Build a filename- rdimport takes metadata in the filename. See metadata pattern below.
      filename = [u.artist,u.title,(u.album or '' rescue ''),((u.publisher+" - ISRC "+u.isrc) or '' rescue ''),(u.copyright or '' rescue ''),(u.composer or '' rescue '')].join("__-__-__")+".wav"
      # Let's copy this to our import path
      FileUtils.cp(in_path, Settings.path_to_import+"/"+filename)
      log = ''
      IO.popen(['rdimport', 
        '--metadata-pattern=%a__-__-__%t__-__-__%l__-__-__%p__-__-__%b__-__-__%m.wav', 
        "--autotrim-level=#{Settings.rivendell_import_autotrim_level}",
        "--segue-level=#{Settings.rivendell_import_segue_level}",
        "--segue-length=#{Settings.rivendell_import_segue_length}",
        Settings.rivendell_import_group,
        ("\""+(Settings.path_to_import+"/"+filename)+"\"")]){|io|log=io.read}
      # We're done with the file now.
      File.delete(Settings.path_to_import+"/"+filename)
      u.atl("INFO", "ImportJob: Imported to Rivendell successfully. Full log follows.")
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
        u.atl("INFO", "ImportJob: Broadcast Wave Format selected (linear PCM)")
        out_path = out_path+".wav"
        FileUtils.cp(in_path, out_path)
        u.atl("INFO", "ImportJob: BWF filesystem write complete, tagging")
        log = ''
        IO.popen(['bwfmetaedit', 
          "--Description=\"#{u.title}\"",
          "--Originator=\"#{u.artist}\"",
          "--OriginatorReference=\"IRISID-#{u.id}-ISRC-#{u.isrc}\"",
          out_path]){|io|log=io.read}
        u.atl("INFO", "ImportJob: BWF chunks written, log follows")
        u.atl("INFO", "ImportJob: #{log}")
        u.imported_okay
      elsif Settings.file_import_format == 'wav'
        u.atl("INFO", "ImportJob: Untagged linear PCM WAV format selected")
        out_path = out_path+".wav"
        FileUtils.cp(in_path, out_path)
        u.atl("INFO", "ImportJob: WAV filesystem write complete")
        u.imported_okay
      else
        u.atl("ERROR", "ImportJob: Unknown format specified- not doing anything! See config/settings.yml for valid options")
        u.import_failure
      end
    end
    u.atl("INFO", "ImportJob: Finished")
  end
  # This chunk of thinking is shared between Myriad and file import modes.
  def export_mp3(u,in_path,out_path)
    log = ''
    IO.popen(['lame', '--preset', 'insane', '--noreplaygain', '--strictly-enforce-ISO', in_path, out_path]){|io|log=io.read}
    u.atl("INFO", "ImportJob: MP3 written to #{out_path}, LAME log follows.")
    u.atl("INFO", "ImportJob: #{log}")
  end
end
