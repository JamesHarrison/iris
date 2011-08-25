require 'fileutils'
class ImportJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "ImportJob: Started")
    in_path = Settings.path_to_import+"/"+u.filename+".normalized.wav"
    if Settings.rivendell_import_enabled == true
      u.atl("INFO", "ImportJob: Importing to Rivendell")
      filename = [u.artist,u.title,(u.album or '' rescue ''),((u.publisher+" - ISRC "+u.isrc) or '' rescue ''),(u.copyright or '' rescue ''),(u.composer or '' rescue '')].join("__-__-__")+".wav"
      FileUtils.mv(in_path, Settings.path_to_import+"/"+filename)
      log = IO.popen(['rdimport', 
        '--metadata-pattern=%a__-__-__%t__-__-__%l__-__-__%p__-__-__%b__-__-__%m.wav', 
        "--autotrim-level=#{Settings.rivendell_import_autotrim_level}",
        "--segue-level=#{Settings.rivendell_import_segue_level}",
        "--segue-length=#{Settings.rivendell_import_segue_length}",
        Settings.rivendell_import_group,
        (Settings.path_to_import+"/"+filename)]).read
      u.atl("INFO", "ImportJob: Imported to Rivendell successfully. Full log follows.")
      u.atl("INFO", "ImportJob: #{log}")
    end
    if Settings.myriad_import_enabled == true
      u.atl("WARN", "ImportJob: Myriad import enabled, but not implemented")
      u.import_failure
    end
    u.imported_okay
    u.atl("INFO", "ImportJob: Finished")
  end
end
