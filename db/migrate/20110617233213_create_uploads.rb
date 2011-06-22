class CreateUploads < ActiveRecord::Migration
  def self.up
    create_table :uploads do |t|
      t.integer :user_id
      t.string :state
      t.string :filename
      t.string :path
      t.integer :cart
      t.integer :current_job_id
      t.string :title
      t.string :artist
      t.string :album
      t.integer :year
      t.integer :length
      t.string :copyright
      t.string :composer
      t.string :publisher
      t.string :isrc
      t.string :genre
      t.integer :bitrate
      t.integer :sample_rate
      t.integer :channels
      t.string :format
      t.string :long_format
      t.integer :content_type
      t.text :log
      t.timestamps
    end
    add_index :uploads, :user_id
    add_index :uploads, :state
  end

  def self.down
    drop_table :uploads
  end
end
