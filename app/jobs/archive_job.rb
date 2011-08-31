require 'fileutils'
# ArchiveJob is intended to encode a high-quality FLAC copy of a WAV file, with appropriate metadata set, for archival purposes.
# Once it is complete, the original WAV is destroyed.
# This allows for original uploads to be stored prior to processing for diagnostic and recovery purposes, but in a nice uniform format.
class NoOutputError < Exception; end
class ArchiveJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "ArchiveJob: Started")
    if Settings.path_to_archive == 'none' and Settings.path_to_orig_backup == 'none'
      u.atl("INFO", "ArchiveJob: Skipping, archival and original backup both disabled")
    else
      in_path = Settings.path_to_import+"/"+u.filename+".wav"
      out_path = Settings.path_to_archive+"/"+u.filename+".flac"
      out_path_orig = Settings.path_to_orig_backup+"/#{u.id}---"+u.filename
      File.delete(out_path) if File.exists?(out_path)
      if Settings.path_to_archive != 'none'
        Dir.mkdir(Settings.path_to_archive) unless File.directory?(Settings.path_to_archive)
        begin
          flac_out = ''
          IO.popen(['flac', '--best', '--tag=TITLE='+u.title, '--tag=ARTIST='+u.artist, '--tag=ALBUM='+u.album, in_path, '-o', out_path]){|io|flac_out = io.read}
          raise(NoOutputError, "flac didn't write anything") unless File.exists?(out_path)
          u.atl("INFO", "ArchiveFileJob: flac conversion finished, wrote to #{out_path}")
        rescue Exception => e
          u.atl("WARN", "ArchiveFileJob: flac conversion failed, #{e.inspect} #{flac_out}")
        end
      else
        u.atl("INFO", "ArchiveJob: Skipping archival")
      end
      if Settings.path_to_orig_backup != 'none'
        Dir.mkdir(Settings.path_to_orig_backup) unless File.directory?(Settings.path_to_orig_backup)
        # Copy the original to our originals archive, and remove the now-useless symlink
        # FIXME: Sort permissions out with nginx so we can move things instead of copying (though across partitions this would be a copy anyway)
        begin
          FileUtils.cp(u.path, out_path_orig)
          if File.exists?(out_path_orig)
            u.atl("INFO", "ArchiveFileJob: Original file backed up")
          else
            u.atl("WARN", "ArchiveFileJob: Original file could not be backed up")
          end
        rescue Exception => e
          u.atl("WARN", "ArchiveFileJob: Original file could not be backed up: #{e.inspect}")
        end
      else
        u.atl("INFO", "ArchiveJob: Skipping original backup")
      end
    end
    u.atl("INFO", "ArchiveJob: Finished")
  end
  def failure;u = Upload.find(self.upload_id);u.mark_failed; end
end
