class UploadWaveform < ActiveRecord::Base
  serialize :data
  belongs_to :upload
end
