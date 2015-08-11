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

ActiveRecord::Schema.define(version: 20150811043130) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "meal_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  add_index "assignments", ["meal_id"], name: "index_assignments_on_meal_id", using: :btree
  add_index "assignments", ["role"], name: "index_assignments_on_role", using: :btree
  add_index "assignments", ["user_id"], name: "index_assignments_on_user_id", using: :btree

  create_table "communities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "households", force: :cascade do |t|
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.string "suffix"
    t.integer "unit_num", null: false
    t.datetime "updated_at", null: false
  end

  add_index "households", ["community_id"], name: "index_households_on_community_id", using: :btree

  create_table "invitations", force: :cascade do |t|
    t.integer "community_id", null: false
    t.integer "meal_id", null: false
  end

  add_index "invitations", ["community_id"], name: "index_invitations_on_community_id", using: :btree
  add_index "invitations", ["meal_id"], name: "index_invitations_on_meal_id", using: :btree

  create_table "locations", force: :cascade do |t|
    t.string "abbrv", limit: 16, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "meals", force: :cascade do |t|
    t.text "allergens", default: "[]", null: false
    t.integer "capacity", null: false
    t.datetime "created_at", null: false
    t.text "dessert"
    t.text "entrees"
    t.text "kids"
    t.integer "location_id"
    t.text "notes"
    t.datetime "served_at", null: false
    t.text "side"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  add_index "meals", ["location_id"], name: "index_meals_on_location_id", using: :btree
  add_index "meals", ["served_at"], name: "index_meals_on_served_at", using: :btree

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.inet "current_sign_in_ip"
    t.datetime "deleted_at"
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "google_email", null: false
    t.string "home_phone"
    t.integer "household_id", null: false
    t.string "last_name", null: false
    t.datetime "last_sign_in_at"
    t.inet "last_sign_in_ip"
    t.string "mobile_phone"
    t.string "provider"
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "work_phone"
  end

  add_foreign_key "assignments", "meals"
  add_foreign_key "assignments", "users"
  add_foreign_key "invitations", "communities"
  add_foreign_key "invitations", "meals"
  add_foreign_key "meals", "locations"
end
