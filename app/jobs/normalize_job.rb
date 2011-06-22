require 'fileutils'
require 'r128'
# NormalizeJob is badly named. While we do normalize in this, the primary thing done here is to trigger copying of the original audio data to FLAC,
# and to do loudness control on incoming data to conform to EBU R128 with a loudness range of 8 and average loudness (integral) of -23 LUFS.
# This is done via magic.
class SoxError < Exception; end
class R128Error < Exception; end
class EcasoundError < Exception; end
class NormalizeJob < Struct.new(:upload_id)
  def perform
    u = Upload.find(self.upload_id)
    u.atl("INFO", "NormalizeJob: Started")
    in_path = Settings.path_to_import+"/"+u.filename+".wav"
    out_path = Settings.path_to_import+"/"+u.filename+".normalized.wav"
    File.delete(out_path) if File.exists?(out_path)
    eca_path = Settings.path_to_import+"/"+u.filename+".eca.wav"
    File.delete(eca_path) if File.exists?(eca_path)
    # First things first: Let's store this track's waveform for pretty rendering purposes
    if !u.upload_waveform
      begin
        wf = UploadWaveform.new
        wf.upload_id = u.id
        wf.data = R128.momentary(in_path, 0.4)
        wf.save!
        u.atl("INFO", "NormalizeJob: Built R128 momentary waveform data")
      rescue Exception => e
        u.atl("WARN", "NormalizeJob: Unable to build momentary waveform: #{e.inspect}")
      end
    end
    # Now let's scan this file and work out what we need to do.
    md = {}
    begin
      md = R128.scan(in_path)
      raise R128Error, "Unable to get R128 LUFS/LRA metadata: #{md.inspect rescue nil}" unless md and md[:lufs] and md[:lra]
    rescue Exception => e
      u.atl("ERROR", "NormalizeJob: Unable to scan file: #{e.inspect}")
      u.normalization_failed
      return
    end
    # We should now have a hash, md, with R128 loudness data. LUFS and LRA are all we really care about. LUFS wants to be -23. Let's start there.
    u.atl("INFO", "NormalizeJob: R128 metadata: #{md.inspect}")
    # Let's work out exactly what we need to do.
    # We're going to adjust gain by so much, and adjust dynamic range by compression by a certain ratio.
    gain = 0.0
    gain_mtp = 0.0 # For MaxTP adjustment
    comp_ratio = 1.0
    # If LUFS is less than target, we want to up the gain if we can- but we have to be careful not to clip.
    if md[:lufs] < -23.0
      gain = -23.0-md[:lufs].to_f
      u.atl("INFO", "NormalizeJob: Track loudness needs amplifying from #{md[:lufs].to_s} LU")
    elsif md[:lufs] > -23.0 
      # If we're above target, turn it down
      gain = -23.0-md[:lufs].to_f
      u.atl("INFO", "NormalizeJob: Track loudness needs reducing from #{md[:lufs].to_s} LU")
    else
      u.atl("INFO", "NormalizeJob: Track loudness does not require adjustment")
    end
    # Now we have the track at -23 LUFS. Now let's look at LRA. If it's > Settings.target_lra then we want to compress it gently.
    if md[:lra] > (Settings.target_lra.to_f+1) # Note the +1 - we don't care about stuff that is so close as to make compressing fairly pointless
      # Compress. But by how much?
      comp_ratio = Settings.target_lra.to_f/md[:lra].to_f
      u.atl("INFO", "NormalizeJob: Track LRA needs reducing by #{(Settings.target_lra.to_f-md[:lra]).to_s} LU, using ratio #{comp_ratio.to_s}")
      # Now we've done a big unknown to our track, let's re-LUFS it.
    elsif md[:lra] < Settings.target_lra.to_f
      u.atl("INFO", "NormalizeJob: Track LRA needs increasing by #{(Settings.target_lra.to_f-md[:lra]).to_s} but we can't/don't want to do this. Track is just badly mastered or low-dynamic-range")
    else
      u.atl("INFO", "NormalizeJob: Track LRA does not require adjustment")
    end
    if comp_ratio != 1.0
      u.atl("INFO", "NormalizeJob: Compressing by ratio #{comp_ratio.to_s}")
      # ecasound -i:"01 New Born.mp3" -o:out_nb.wav -eca:69,0.01,0.8,
      begin
        ecaout = IO.popen(['ecasound', '-i', in_path, '-o', eca_path, "-eca:69,1.0,0.5,#{comp_ratio.to_s}"]).read
        raise(EcasoundError, "ecasound didn't write any data: #{ecaout.to_s}") unless File.exists?(eca_path)
        md = R128.scan(eca_path)
        gain = -23.0-md[:lufs] if md[:lufs] != -23.0
        u.atl("INFO", "NormalizeJob: Compressed by ratio #{comp_ratio.to_s}, new gain adjustment: #{gain.inspect}, new metadata: #{md.inspect}")
      rescue Exception => e
        u.atl("ERROR", "NormalizeJob: Unable to compress: #{e.inspect}")
      end
    end
    soxout = ''
    # We need to turn this down a little more- we're in danger of clipping on DACs and whatnot.
    if md[:true_peak_dbtp] > -1.0
      gain_mtp = -1.0-md[:true_peak_dbtp] # This is by how much we need to adjust the volume in dB, so now let's work out how much we need to tweak our gain param to allow that
      if gain > gain_mtp # If we're adjusting by less (negative numbers, remember!), we need to add to that reduction
        gain = gain - (gain - gain_mtp) # TODO: Check this, maths-wise
      end
    end
    if gain != 0.0
      u.atl("INFO", "NormalizeJob: Adjusting gain by #{gain.inspect}")
      begin
        # Explanation on sox options: gain followed by a number changes the amplitude. The -l option should be applied when adding gain- this adds a limiter to prevent clipping. -D disables automatic dithering.
        if gain > 0
          soxout = IO.popen(['sox', (File.exists?(eca_path) ? eca_path : in_path), out_path, 'gain', '-l', gain.to_s]).read
        else
          soxout = IO.popen(['sox', (File.exists?(eca_path) ? eca_path : in_path), out_path, 'gain', gain.to_s]).read
        end
        raise(SoxError, "sox didn't write any data: #{soxout}") unless File.exists?(out_path)
        u.atl("INFO", "NormalizeJob: Adjusted gain by #{gain.inspect}")
        u.atl("WARN", "NormalizeJob: sox reported clipping: #{soxout.inspect}")if soxout.include?("clipped")
      rescue Exception => e
        u.atl("ERROR","NormalizeJob: Unable to adjust gain: #{e.inspect}")
      end
    end
    FileUtils.mv(eca_path, out_path) if File.exists?(eca_path) and !File.exists?(out_path)
    u.atl("INFO", "NormalizeJob: Finished")
    u.normalization_okay
  end
end
