# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110619214933) do

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "upload_waveforms", :force => true do |t|
    t.integer  "upload_id"
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "uploads", :force => true do |t|
    t.integer  "user_id"
    t.string   "state"
    t.string   "filename"
    t.string   "path"
    t.integer  "cart"
    t.integer  "current_job_id"
    t.string   "title"
    t.string   "artist"
    t.string   "album"
    t.integer  "year"
    t.integer  "length"
    t.string   "copyright"
    t.string   "composer"
    t.string   "publisher"
    t.string   "isrc"
    t.string   "genre"
    t.integer  "bitrate"
    t.integer  "sample_rate"
    t.integer  "channels"
    t.string   "format"
    t.string   "long_format"
    t.integer  "content_type"
    t.text     "log"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "uploads", ["state"], :name => "index_uploads_on_state"
  add_index "uploads", ["user_id"], :name => "index_uploads_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "name",                                                    :null => false
    t.string   "email",                               :default => "",     :null => false
    t.string   "encrypted_password",   :limit => 128, :default => "",     :null => false
    t.string   "role",                                :default => "user", :null => false
    t.string   "reset_password_token"
    t.string   "remember_token"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                       :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.integer  "failed_attempts",                     :default => 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.string   "authentication_token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true
  add_index "users", ["unlock_token"], :name => "index_users_on_unlock_token", :unique => true

end
