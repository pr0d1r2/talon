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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170603183934) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "downloads", force: :cascade do |t|
    t.string "key", null: false
    t.string "title", null: false
    t.string "extractor", null: false
    t.string "webpage_url", null: false
    t.integer "duration"
    t.string "thumbnail_file_name"
    t.string "thumbnail_content_type"
    t.integer "thumbnail_file_size"
    t.datetime "thumbnail_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_downloads_on_key"
    t.index ["webpage_url"], name: "index_downloads_on_webpage_url"
  end

end
