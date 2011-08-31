# ExtractFileJob pulls data out of anything possible and stuffs it into a WAV for subsequent operations.
class NoOutputError < Exception; end
class ExtractFileJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "ExtractFileJob: Started")
    Dir.mkdir(Settings.path_to_import) unless File.directory?(Settings.path_to_import)
    in_path = Settings.path_to_uploads+"/"+u.filename
    out_path = Settings.path_to_import+"/"+u.filename+".wav"
    File.delete(out_path) if File.exists?(out_path)
    begin
      ffmpeg_out = ''
      IO.popen(['ffmpeg', '-i', in_path, out_path]){|io|ffmpeg_out = io.read}
      raise(NoOutputError, "ffmpeg didn't write anything") unless File.exists?(out_path)
      u.atl("INFO", "ExtractFileJob: ffmpeg conversion finished")
      u.unpacked_okay
    rescue Exception => e
      u.atl("DEBUG", "ExtractFileJob: ffmpeg conversion failed, #{e.inspect} #{ffmpeg_out}")
      u.unpacking_failed
    end
    u.atl("INFO", "ExtractFileJob: Finished")
  end
  def failure;u = Upload.find(self.upload_id);u.mark_failed; end
end
