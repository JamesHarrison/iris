class Upload < ActiveRecord::Base
  attr_accessible :filename, :cart_number, :current_job_id, :title, :artist, :album, :year, :copyright, :composer, :publisher, :isrc, :genre, :bitrate, :log
  belongs_to :user
  has_many :upload_waveforms
  def atl(level, message)
    self.transaction do
      self.log = "" unless self.log
      self.log = self.log + "\n#{Time.now}: #{level} - #{message}"
      self.save
    end
  end
  after_create :start_metadata
  def start_metadata
    enqueue_and_log(MetadataJob, 10)
  end
  def enqueue_and_log(job_object, priority=20)
    job = Delayed::Job.enqueue job_object.new(self.id), :priority => priority
    self.current_job_id = job.id
    self.save!
  end
  # enqueue_and_log(FilterJob, 10)
  state_machine :state, :initial => :uploaded do
    after_transition :uploaded => :metadata_extracted do |u,t|u.enqueue_and_log(FilterJob, 15) end
    after_transition [:metadata_extracted, :needs_review] => :filtered do |u,t|u.enqueue_and_log(ExtractFileJob, 20) end
    after_transition :filtered => :unpacked do |u,t|u.enqueue_and_log(ArchiveJob, 25);u.enqueue_and_log(NormalizeJob, 30) end
    #after_transition :metadata_extracted => :needs_review do |u,t|u.enqueue_and_log(FilterJob, 15) end
    #after_transition :needs_review => :rejected do |u,t|u.enqueue_and_log(FilterJob, 15) end
    #after_transition :filtered => :normalized do |u,t|u.enqueue_and_log(FilterJob, 15) end
    #after_transition :metadata_extracted => :failed do |u,t|u.enqueue_and_log(FilterJob, 15) end
    #after_transition :filtered => :failed do |u,t|u.enqueue_and_log(FilterJob, 15) end
    #after_transition :metadata_extracted => :duplicate do |u,t|u.enqueue_and_log(FilterJob, 15) end

    event :got_metadata do
      transition :uploaded => :metadata_extracted
      # Queue filter job
    end
    event :pass_filtering do
      transition :metadata_extracted => :filtered
      # Queue normalize job
    end
    event :fail_filtering do
      transition :metadata_extracted => :needs_review
      # Email head of music and/or uploader and/or other peeps
    end
    event :fail_filtering_drm do
      transition :metadata_extracted => :failed
      # Email -somebody-, probably.
    end
    event :no_lyrics_available do
      transition :metadata_extracted => :filtered
      # Queue normalize job
    end
    event :unpacked_okay do
      transition :filtered => :unpacked
    end
    event :unpacking_failed do
      transition :filtered => :failed
    end
    event :normalization_okay do
      transition :unpacked => :normalized
      # Queue import job
    end
    event :normalization_failed do
      transition :unpacked => :failed
      # Email admin
    end
    event :fail_as_duplicate do
      transition :metadata_extracted => :duplicate
    end
    event :imported_okay do
      transition :normalized => :imported
    end
    event :import_failure do
      transition :normalized => :failed
    end
    event :reject do
      transition :needs_review => :rejected
      transition :needs_approval => :rejected
      # Email head of music
    end
    event :approve do
      transition :needs_review => :filtered
      transition :needs_approval => :imported
      # Queue normalize job
    end
    state :uploaded do
      # We're a new file, just been uploaded
    end
    state :metadata_extracted do
      # We've gotten metadata out of this successfully, or we think we're not something that should have metadata
    end
    state :filtered do
      # We've had a look at the lyrics and this looks fine. That, or we can't get the lyrics and we assume it's okay.
    end
    state :unpacked do
      # We've pulled this file out to pure WAV data.
    end
    state :needs_review do
      # We looked at the lyrics and we're not immediately impressed. Needs human intervention.
    end
    state :normalized do
      # We've now successfully normalized this and done loudness control
    end
    state :needs_approval do
      # We're waiting for approval before import
    end
    state :failed do
      # Something went wrong at some stage.
    end
    state :duplicate do
      # We've found a copy of this already in the system.
    end
    state :imported do
      # We're in the system successfully!
    end
    state :rejected do
      # We needed reviewing but a human has rejected this upload
    end
  end
end
