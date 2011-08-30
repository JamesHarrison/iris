# Very simple class to use r128-scanner from within Ruby to get whole-track LUFS, LRA, sample/true peak/true peak dBTP, as well as momentary waveform data
class R128
  def self.scan(path)
    print "Scanning #{path}"
    out = ''
    IO.popen(['r128-scanner', '-p', 'all', '-l', path]){|io|out = io.read}
    print "Got: #{out}"
    d = out.split("\n")[0].split(",")
    return {:lufs=>d[0].to_f, :lra=>d[1].to_f, :sample_peak=>d[2].to_f, :true_peak_float=>d[3].to_f, :true_peak_dbtp=>d[4].to_f}
  end
  def self.momentary(path,interval=0.4)
    out = ''
    IO.popen(['r128-scanner', '-m', interval.to_s, path]){|io|out = io.read}
    d = out.split("\n").map{|v|v.gsub("\n","").strip}
    d.delete("-inf")
    return d.map{|v|v.to_f}
  end
end
