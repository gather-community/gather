# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20150722145704) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "communities", force: :cascade do |t|
    t.string   "name",       null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "households", force: :cascade do |t|
    t.string   "name",         null: false
    t.integer  "unit_num",     null: false
    t.integer  "community_id", null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "households", ["community_id"], name: "index_households_on_community_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.integer  "sign_in_count",      default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.string   "provider"
    t.string   "uid"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "google_email",                   null: false
    t.string   "email",                          null: false
    t.string   "first_name",                     null: false
    t.string   "last_name",                      null: false
    t.string   "home_phone"
    t.string   "mobile_phone"
    t.string   "work_phone"
    t.integer  "household_id",                   null: false
  end

end
