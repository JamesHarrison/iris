class ImportJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "ImportJob: Started")
    if Settings.rivendell_import_enabled == true
      u.atl("WARN", "ImportJob: Rivendell import enabled, but not implemented")
      u.import_failure
    end
    if Settings.myriad_import_enabled == true
      u.atl("WARN", "ImportJob: Myriad import enabled, but not implemented")
      u.import_failure
    end
    u.imported_okay
    u.atl("INFO", "ImportJob: Finished")
  end
end