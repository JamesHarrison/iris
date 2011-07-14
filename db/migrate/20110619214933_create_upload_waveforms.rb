class CreateUploadWaveforms < ActiveRecord::Migration
  def self.up
    create_table :upload_waveforms do |t|
      t.integer :upload_id
      t.text :data
      t.string :label
      t.timestamps
    end
  end

  def self.down
    drop_table :upload_waveforms
  end
end
