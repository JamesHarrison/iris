# FilterJob handles filtering incoming files based on their incoming quality, format, and on lyrics if possible.
# Metadata for this job is extracted and stored against uploads by the Metadata job
# Anything that fails filtering is placed in a queue to be reviewed.
# Deduplication is also done here.
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
        if u.bitrate < 128 # Too low-quality, bitrate-wise?
          u.atl("ERROR", "FilterJob: Bitrate (#{u.bitrate}) is below threshold of 128kbps. Flagging for review.")
          u.fail_filtering
        else
          u.atl("INFO", "FilterJob: Bitrate (#{u.bitrate}) is above threshold of 128kbps, passed")
          if u.sample_rate < 44100 # Sample rate too low?
            u.atl("ERROR", "FilterJob: Sample rate (#{u.sample_rate}) is below threshold of 44100. Flagging for review.")
            u.fail_filtering
          else
            u.atl("INFO", "FilterJob: Sample rate (#{u.sample_rate}) is above threshold of 44100, passed")
            quality_okay = true # We're good on both raw technical quality counts.
          end
        end
      else
        u.atl("ERROR", "FilterJob: No bitrate stored. Unable to enforce quality. Flagging for review.")
      end
    end
    # TODO: Lyric filtering
    u.atl("INFO", "FilterJob: Lyric filtering not implemented yet, passing by default")
    lyrics_okay = true
    u.atl("INFO", "FilterJob: Finished")
    if quality_okay and lyrics_okay
      u.pass_filtering
    end
  end
end
