# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_03_22_202824) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", id: :serial, force: :cascade do |t|
    t.decimal "balance_due", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 10, scale: 2
    t.decimal "current_balance", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "due_last_statement", precision: 10, scale: 2
    t.integer "household_id", null: false
    t.integer "last_statement_id"
    t.date "last_statement_on"
    t.decimal "total_new_charges", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total_new_credits", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_accounts_on_cluster_id"
    t.index ["community_id", "household_id"], name: "index_accounts_on_community_id_and_household_id", unique: true
    t.index ["community_id"], name: "index_accounts_on_community_id"
    t.index ["household_id"], name: "index_accounts_on_household_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "billing_template_member_types", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.bigint "member_type_id", null: false
    t.bigint "template_id", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cluster_id"], name: "index_billing_template_member_types_on_cluster_id"
    t.index ["member_type_id"], name: "index_billing_template_member_types_on_member_type_id"
    t.index ["template_id"], name: "index_billing_template_member_types_on_template_id"
  end

  create_table "billing_templates", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.string "code", limit: 16, null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.string "description", limit: 255, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.index ["cluster_id"], name: "index_billing_templates_on_cluster_id"
    t.index ["community_id"], name: "index_billing_templates_on_community_id"
  end

  create_table "calendar_events", id: :serial, force: :cascade do |t|
    t.integer "calendar_id", null: false
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.datetime "ends_at", null: false
    t.string "kind"
    t.integer "meal_id"
    t.string "name", limit: 24, null: false
    t.text "note"
    t.integer "sponsor_id"
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_id"], name: "index_calendar_events_on_calendar_id"
    t.index ["cluster_id"], name: "index_calendar_events_on_cluster_id"
    t.index ["creator_id"], name: "index_calendar_events_on_creator_id"
    t.index ["meal_id"], name: "index_calendar_events_on_meal_id"
    t.index ["sponsor_id"], name: "index_calendar_events_on_sponsor_id"
    t.index ["starts_at"], name: "index_calendar_events_on_starts_at"
  end

  create_table "calendar_guideline_inclusions", id: :serial, force: :cascade do |t|
    t.integer "calendar_id", null: false
    t.integer "cluster_id", null: false
    t.integer "shared_guidelines_id", null: false
    t.index ["calendar_id", "shared_guidelines_id"], name: "index_reservation_guideline_inclusions", unique: true
    t.index ["cluster_id"], name: "index_calendar_guideline_inclusions_on_cluster_id"
  end

  create_table "calendar_nodes", id: :serial, force: :cascade do |t|
    t.string "abbrv", limit: 6
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "default_calendar_view", default: "week", null: false
    t.bigint "group_id"
    t.text "guidelines"
    t.boolean "meal_hostable", default: false, null: false
    t.string "name", limit: 24, null: false
    t.integer "rank", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_calendar_nodes_on_cluster_id"
    t.index ["community_id", "name"], name: "index_calendar_nodes_on_community_id_and_name", unique: true
    t.index ["community_id"], name: "index_calendar_nodes_on_community_id"
    t.index ["group_id"], name: "index_calendar_nodes_on_group_id"
    t.check_constraint :group_id_null, "(((type)::text = 'Calendars::Calendar'::text) OR (((type)::text = 'Calendars::Group'::text) AND (group_id IS NULL)))"
  end

  create_table "calendar_protocolings", id: :serial, force: :cascade do |t|
    t.integer "calendar_id", null: false
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.integer "protocol_id", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_id", "protocol_id"], name: "protocolings_unique", unique: true
    t.index ["cluster_id"], name: "index_calendar_protocolings_on_cluster_id"
  end

  create_table "calendar_protocols", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.time "fixed_end_time"
    t.time "fixed_start_time"
    t.jsonb "kinds"
    t.integer "max_days_per_year"
    t.integer "max_lead_days"
    t.integer "max_length_minutes"
    t.integer "max_minutes_per_year"
    t.string "name", null: false
    t.string "other_communities"
    t.text "pre_notice"
    t.boolean "requires_kind"
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_calendar_protocols_on_cluster_id"
    t.index ["community_id"], name: "index_calendar_protocols_on_community_id"
  end

  create_table "calendar_shared_guidelines", id: :serial, force: :cascade do |t|
    t.text "body", null: false
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_calendar_shared_guidelines_on_cluster_id"
    t.index ["community_id"], name: "index_calendar_shared_guidelines_on_community_id"
  end

  create_table "clusters", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 20, null: false
    t.string "sso_secret", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_clusters_on_name"
  end

  create_table "communities", id: :serial, force: :cascade do |t|
    t.string "abbrv", limit: 2
    t.string "calendar_token", null: false
    t.integer "cluster_id", null: false
    t.string "country_code", limit: 2, default: "US", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 20, null: false
    t.jsonb "settings"
    t.string "slug", null: false
    t.string "sso_secret", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_communities_on_cluster_id"
    t.index ["name"], name: "index_communities_on_name", unique: true
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at"
    t.datetime "failed_at"
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "locked_at"
    t.string "locked_by"
    t.integer "priority", default: 0, null: false
    t.string "queue"
    t.datetime "run_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "domain_ownerships", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.bigint "domain_id", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cluster_id", "community_id", "domain_id"], name: "index_domain_ownerships_unique", unique: true
    t.index ["cluster_id"], name: "index_domain_ownerships_on_cluster_id"
    t.index ["community_id"], name: "index_domain_ownerships_on_community_id"
    t.index ["domain_id"], name: "index_domain_ownerships_on_domain_id"
  end

  create_table "domains", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.string "name", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cluster_id"], name: "index_domains_on_cluster_id"
    t.index ["name"], name: "index_domains_on_name", unique: true
  end

  create_table "gdrive_configs", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.jsonb "credentials", null: false
    t.datetime "last_scanned_at"
    t.string "owner_email", limit: 128, null: false
    t.string "root_folder_id", limit: 128, null: false
    t.jsonb "token"
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cluster_id"], name: "index_gdrive_configs_on_cluster_id"
    t.index ["community_id"], name: "index_gdrive_configs_on_community_id"
  end

  create_table "gdrive_stray_files", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.string "file_id", limit: 128, null: false
    t.string "mime_type", limit: 128, null: false
    t.string "owner_email", limit: 128, null: false
    t.string "parent_id", limit: 128, null: false
    t.text "path", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cluster_id", "community_id", "file_id"], name: "unique_by_cmty_and_file", unique: true
    t.index ["cluster_id"], name: "index_gdrive_stray_files_on_cluster_id"
    t.index ["community_id"], name: "index_gdrive_stray_files_on_community_id"
    t.index ["mime_type"], name: "index_gdrive_stray_files_on_mime_type"
    t.index ["owner_email"], name: "index_gdrive_stray_files_on_owner_email"
  end

  create_table "group_affiliations", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.bigint "community_id", null: false
    t.bigint "group_id", null: false
    t.index ["cluster_id"], name: "index_group_affiliations_on_cluster_id"
    t.index ["community_id", "group_id"], name: "index_group_affiliations_on_community_id_and_group_id", unique: true
    t.index ["community_id"], name: "index_group_affiliations_on_community_id"
    t.index ["group_id"], name: "index_group_affiliations_on_group_id"
  end

  create_table "group_mailman_lists", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.bigint "domain_id", null: false
    t.bigint "group_id", null: false
    t.boolean "managers_can_administer", default: false, null: false
    t.boolean "managers_can_moderate", default: false, null: false
    t.string "name", null: false
    t.string "remote_id"
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cluster_id"], name: "index_group_mailman_lists_on_cluster_id"
    t.index ["domain_id"], name: "index_group_mailman_lists_on_domain_id"
    t.index ["group_id"], name: "index_group_mailman_lists_on_group_id"
    t.index ["name", "domain_id"], name: "index_group_mailman_lists_on_name_and_domain_id", unique: true
    t.index ["name"], name: "index_group_mailman_lists_on_name"
    t.index ["remote_id"], name: "index_group_mailman_lists_on_remote_id", unique: true
  end

  create_table "group_mailman_users", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.string "remote_id", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.index ["cluster_id"], name: "index_group_mailman_users_on_cluster_id"
    t.index ["remote_id"], name: "index_group_mailman_users_on_remote_id", unique: true
    t.index ["user_id"], name: "index_group_mailman_users_on_user_id", unique: true
  end

  create_table "group_memberships", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.bigint "group_id", null: false
    t.string "kind", limit: 32, default: "joiner", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.index ["cluster_id"], name: "index_group_memberships_on_cluster_id"
    t.index ["group_id", "user_id"], name: "index_group_memberships_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "availability", limit: 10, default: "closed", null: false
    t.boolean "can_administer_email_lists", default: false, null: false
    t.boolean "can_moderate_email_lists", default: false, null: false
    t.boolean "can_request_jobs", default: false, null: false
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "description", limit: 255
    t.string "kind", limit: 32, default: "committee", null: false
    t.string "name", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_groups_on_cluster_id"
  end

  create_table "households", id: :serial, force: :cascade do |t|
    t.string "alternate_id"
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "garage_nums"
    t.string "keyholders"
    t.bigint "member_type_id"
    t.string "name", limit: 50, null: false
    t.integer "unit_num"
    t.string "unit_suffix"
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_households_on_cluster_id"
    t.index ["community_id", "name"], name: "index_households_on_community_id_and_name", unique: true
    t.index ["community_id"], name: "index_households_on_community_id"
    t.index ["deactivated_at"], name: "index_households_on_deactivated_at"
    t.index ["member_type_id"], name: "index_households_on_member_type_id"
    t.index ["name"], name: "index_households_on_name"
  end

  create_table "meal_assignments", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.integer "cook_menu_reminder_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "meal_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["cluster_id"], name: "index_meal_assignments_on_cluster_id"
    t.index ["meal_id"], name: "index_meal_assignments_on_meal_id"
    t.index ["role_id"], name: "index_meal_assignments_on_role_id"
    t.index ["user_id"], name: "index_meal_assignments_on_user_id"
  end

  create_table "meal_cost_parts", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.bigint "cost_id", null: false
    t.datetime "created_at", null: false
    t.bigint "type_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2
    t.index ["cluster_id"], name: "index_meal_cost_parts_on_cluster_id"
    t.index ["cost_id"], name: "index_meal_cost_parts_on_cost_id"
    t.index ["type_id", "cost_id"], name: "index_meal_cost_parts_on_type_id_and_cost_id", unique: true
    t.index ["type_id"], name: "index_meal_cost_parts_on_type_id"
  end

  create_table "meal_costs", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.decimal "ingredient_cost", precision: 10, scale: 2, null: false
    t.string "meal_calc_type"
    t.integer "meal_id", null: false
    t.string "pantry_calc_type"
    t.decimal "pantry_cost", precision: 10, scale: 2, null: false
    t.decimal "pantry_fee", precision: 10, scale: 2
    t.string "payment_method", null: false
    t.bigint "reimbursee_id"
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meal_costs_on_cluster_id"
    t.index ["meal_id"], name: "index_meal_costs_on_meal_id"
    t.index ["reimbursee_id"], name: "index_meal_costs_on_reimbursee_id"
  end

  create_table "meal_formula_parts", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.datetime "created_at", null: false
    t.bigint "formula_id", null: false
    t.decimal "portion_size", precision: 10, scale: 2, null: false
    t.integer "rank", null: false
    t.decimal "share", precision: 10, scale: 4, null: false
    t.bigint "type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meal_formula_parts_on_cluster_id"
    t.index ["formula_id", "type_id"], name: "index_meal_formula_parts_on_formula_id_and_type_id", unique: true
    t.index ["formula_id"], name: "index_meal_formula_parts_on_formula_id"
    t.index ["type_id"], name: "index_meal_formula_parts_on_type_id"
  end

  create_table "meal_formula_roles", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.datetime "created_at", null: false
    t.bigint "formula_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meal_formula_roles_on_cluster_id"
    t.index ["formula_id"], name: "index_meal_formula_roles_on_formula_id"
    t.index ["role_id"], name: "index_meal_formula_roles_on_role_id"
  end

  create_table "meal_formulas", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.boolean "is_default", default: false, null: false
    t.string "meal_calc_type", null: false
    t.string "name", null: false
    t.string "pantry_calc_type", null: false
    t.decimal "pantry_fee", precision: 10, scale: 4, null: false
    t.boolean "pantry_reimbursement", default: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meal_formulas_on_cluster_id"
    t.index ["community_id"], name: "index_meal_formulas_on_community_id"
    t.index ["deactivated_at"], name: "index_meal_formulas_on_deactivated_at"
  end

  create_table "meal_imports", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.jsonb "errors_by_row"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.index ["cluster_id"], name: "index_meal_imports_on_cluster_id"
    t.index ["community_id"], name: "index_meal_imports_on_community_id"
    t.index ["user_id"], name: "index_meal_imports_on_user_id"
  end

  create_table "meal_invitations", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.integer "meal_id", null: false
    t.index ["cluster_id"], name: "index_meal_invitations_on_cluster_id"
    t.index ["community_id", "meal_id"], name: "index_meal_invitations_on_community_id_and_meal_id", unique: true
    t.index ["community_id"], name: "index_meal_invitations_on_community_id"
    t.index ["meal_id"], name: "index_meal_invitations_on_meal_id"
  end

  create_table "meal_messages", id: :serial, force: :cascade do |t|
    t.text "body", null: false
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", default: "normal", null: false
    t.integer "meal_id", null: false
    t.string "recipient_type", null: false
    t.integer "sender_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "meal_resourcings", id: :serial, force: :cascade do |t|
    t.integer "calendar_id", null: false
    t.integer "cluster_id", null: false
    t.integer "meal_id", null: false
    t.integer "prep_time", null: false
    t.integer "total_time", null: false
    t.index ["cluster_id"], name: "index_meal_resourcings_on_cluster_id"
    t.index ["meal_id", "calendar_id"], name: "index_meal_resourcings_on_meal_id_and_calendar_id", unique: true
  end

  create_table "meal_roles", force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.integer "count_per_meal", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.text "description", null: false
    t.boolean "double_signups_allowed", default: false
    t.integer "shift_end"
    t.integer "shift_start"
    t.string "special", limit: 32
    t.string "time_type", limit: 32, default: "date_time", null: false
    t.string "title", limit: 128, null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id", "community_id", "title"], name: "index_meal_roles_on_cluster_id_and_community_id_and_title", where: "(deactivated_at IS NULL)"
    t.index ["cluster_id"], name: "index_meal_roles_on_cluster_id"
  end

  create_table "meal_signup_parts", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.integer "count", null: false
    t.datetime "created_at", null: false
    t.bigint "signup_id", null: false
    t.bigint "type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meal_signup_parts_on_cluster_id"
    t.index ["signup_id"], name: "index_meal_signup_parts_on_signup_id"
    t.index ["type_id", "signup_id"], name: "index_meal_signup_parts_on_type_id_and_signup_id", unique: true
    t.index ["type_id"], name: "index_meal_signup_parts_on_type_id"
  end

  create_table "meal_signups", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.text "comments"
    t.datetime "created_at", null: false
    t.integer "household_id", null: false
    t.integer "meal_id", null: false
    t.boolean "notified", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meal_signups_on_cluster_id"
    t.index ["household_id", "meal_id"], name: "index_meal_signups_on_household_id_and_meal_id", unique: true
    t.index ["household_id"], name: "index_meal_signups_on_household_id"
    t.index ["meal_id"], name: "index_meal_signups_on_meal_id"
    t.index ["notified"], name: "index_meal_signups_on_notified"
  end

  create_table "meal_types", force: :cascade do |t|
    t.string "category", limit: 32
    t.bigint "cluster_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "name", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meal_types_on_cluster_id"
    t.index ["community_id"], name: "index_meal_types_on_community_id"
  end

  create_table "meals", id: :serial, force: :cascade do |t|
    t.jsonb "allergens", default: [], null: false
    t.datetime "auto_close_time"
    t.integer "capacity", null: false
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.text "dessert"
    t.text "entrees"
    t.integer "formula_id", null: false
    t.text "kids"
    t.datetime "menu_posted_at"
    t.boolean "no_allergens", default: false, null: false
    t.text "notes"
    t.datetime "served_at", null: false
    t.text "side"
    t.string "status", default: "open", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_meals_on_cluster_id"
    t.index ["creator_id"], name: "index_meals_on_creator_id"
    t.index ["formula_id"], name: "index_meals_on_formula_id"
    t.index ["served_at"], name: "index_meals_on_served_at"
  end

  create_table "people_emergency_contacts", id: :serial, force: :cascade do |t|
    t.string "alt_phone"
    t.integer "cluster_id", null: false
    t.string "country_code", limit: 2, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "household_id"
    t.string "location", null: false
    t.string "main_phone", null: false
    t.string "name", null: false
    t.string "relationship", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_people_emergency_contacts_on_cluster_id"
    t.index ["household_id"], name: "index_people_emergency_contacts_on_household_id"
  end

  create_table "people_guardianships", id: :serial, force: :cascade do |t|
    t.integer "child_id", null: false
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.integer "guardian_id", null: false
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_people_guardianships_on_child_id"
    t.index ["cluster_id"], name: "index_people_guardianships_on_cluster_id"
    t.index ["guardian_id"], name: "index_people_guardianships_on_guardian_id"
  end

  create_table "people_member_types", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.string "name", limit: 64, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cluster_id"], name: "index_people_member_types_on_cluster_id"
    t.index ["community_id", "name"], name: "index_people_member_types_on_community_id_and_name", unique: true
    t.index ["community_id"], name: "index_people_member_types_on_community_id"
  end

  create_table "people_memorial_messages", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.bigint "cluster_id"
    t.datetime "created_at", precision: 6, null: false
    t.bigint "memorial_id", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["author_id"], name: "index_people_memorial_messages_on_author_id"
    t.index ["cluster_id"], name: "index_people_memorial_messages_on_cluster_id"
    t.index ["created_at"], name: "index_people_memorial_messages_on_created_at"
    t.index ["memorial_id"], name: "index_people_memorial_messages_on_memorial_id"
  end

  create_table "people_memorials", force: :cascade do |t|
    t.integer "birth_year"
    t.bigint "cluster_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.integer "death_year", null: false
    t.text "obituary"
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id", null: false
    t.index ["cluster_id"], name: "index_people_memorials_on_cluster_id"
    t.index ["user_id"], name: "index_people_memorials_on_user_id", unique: true
  end

  create_table "people_pets", id: :serial, force: :cascade do |t|
    t.string "caregivers"
    t.integer "cluster_id", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.text "health_issues"
    t.integer "household_id", null: false
    t.string "name"
    t.string "species"
    t.datetime "updated_at", null: false
    t.string "vet"
    t.index ["cluster_id"], name: "index_people_pets_on_cluster_id"
    t.index ["household_id"], name: "index_people_pets_on_household_id"
  end

  create_table "people_vehicles", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "household_id", null: false
    t.string "make"
    t.string "model"
    t.string "plate", limit: 10
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_people_vehicles_on_cluster_id"
    t.index ["household_id"], name: "index_people_vehicles_on_household_id"
  end

  create_table "reminder_deliveries", force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deliver_at", null: false
    t.bigint "meal_id"
    t.integer "reminder_id", null: false
    t.bigint "shift_id"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["deliver_at"], name: "index_reminder_deliveries_on_deliver_at"
    t.index ["meal_id"], name: "index_reminder_deliveries_on_meal_id"
    t.index ["reminder_id"], name: "index_reminder_deliveries_on_reminder_id"
    t.index ["shift_id"], name: "index_reminder_deliveries_on_shift_id"
    t.check_constraint :reminder_deliveries_741100539, "(((shift_id IS NOT NULL) AND (meal_id IS NULL)) OR ((meal_id IS NOT NULL) AND (shift_id IS NULL)))"
  end

  create_table "reminders", force: :cascade do |t|
    t.string "abs_rel", default: "relative", null: false
    t.datetime "abs_time"
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id"
    t.string "note"
    t.decimal "rel_magnitude", precision: 10, scale: 2
    t.string "rel_unit_sign"
    t.bigint "role_id"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id", "job_id"], name: "index_reminders_on_cluster_id_and_job_id"
    t.index ["role_id"], name: "index_reminders_on_role_id"
    t.check_constraint :reminders_850637520, "(((role_id IS NOT NULL) AND (job_id IS NULL)) OR ((job_id IS NOT NULL) AND (role_id IS NULL)))"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.string "name"
    t.integer "resource_id"
    t.string "resource_type"
    t.datetime "updated_at"
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["name"], name: "index_roles_on_name"
  end

  create_table "statements", id: :serial, force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.date "due_on"
    t.decimal "prev_balance", precision: 10, scale: 2, null: false
    t.date "prev_stmt_on"
    t.boolean "reminder_sent", default: false, null: false
    t.decimal "total_due", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_statements_on_account_id"
    t.index ["cluster_id"], name: "index_statements_on_cluster_id"
    t.index ["created_at"], name: "index_statements_on_created_at"
    t.index ["due_on"], name: "index_statements_on_due_on"
  end

  create_table "transactions", id: :serial, force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "cluster_id", null: false
    t.string "code", limit: 16, null: false
    t.datetime "created_at", null: false
    t.string "description", limit: 255, null: false
    t.date "incurred_on", null: false
    t.integer "quantity"
    t.integer "statement_id"
    t.integer "statementable_id"
    t.string "statementable_type", limit: 32
    t.decimal "unit_price", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["cluster_id"], name: "index_transactions_on_cluster_id"
    t.index ["code"], name: "index_transactions_on_code"
    t.index ["incurred_on"], name: "index_transactions_on_incurred_on"
    t.index ["statement_id"], name: "index_transactions_on_statement_id"
    t.index ["statementable_id", "statementable_type"], name: "index_transactions_on_statementable_id_and_statementable_type"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "allergies"
    t.string "alternate_id"
    t.date "birthdate"
    t.string "calendar_token"
    t.boolean "child", default: false, null: false
    t.integer "cluster_id", null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.inet "current_sign_in_ip"
    t.datetime "deactivated_at"
    t.string "doctor"
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.boolean "fake", default: false, null: false
    t.string "first_name", null: false
    t.string "google_email"
    t.string "home_phone"
    t.integer "household_id", null: false
    t.integer "job_choosing_proxy_id"
    t.date "joined_on"
    t.string "last_name", null: false
    t.datetime "last_sign_in_at"
    t.inet "last_sign_in_ip"
    t.text "medical"
    t.string "mobile_phone"
    t.string "preferred_contact"
    t.jsonb "privacy_settings", default: {}, null: false
    t.string "provider"
    t.datetime "remember_created_at"
    t.string "remember_token"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "school"
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.string "work_phone"
    t.index ["alternate_id"], name: "index_users_on_alternate_id"
    t.index ["cluster_id"], name: "index_users_on_cluster_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deactivated_at"], name: "index_users_on_deactivated_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_email"], name: "index_users_on_google_email", unique: true
    t.index ["household_id"], name: "index_users_on_household_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint :children_not_confirmed, "((child = false) OR (confirmed_at IS NULL))"
    t.check_constraint :email_presence, "((child = true) OR (deactivated_at IS NOT NULL) OR ((email IS NOT NULL) AND ((email)::text !~ '^\\s*$'::text)))"
    t.check_constraint :unconfirmed_if_no_email, "((email IS NOT NULL) OR (confirmed_at IS NULL))"
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.integer "role_id"
    t.integer "user_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
  end

  create_table "wiki_page_versions", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.string "comment"
    t.text "content"
    t.integer "number", null: false
    t.integer "page_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "updater_id"
    t.index ["cluster_id"], name: "index_wiki_page_versions_on_cluster_id"
    t.index ["page_id", "number"], name: "index_wiki_page_versions_on_page_id_and_number", unique: true
    t.index ["page_id"], name: "index_wiki_page_versions_on_page_id"
    t.index ["updater_id"], name: "index_wiki_page_versions_on_updater_id"
  end

  create_table "wiki_pages", id: :serial, force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "creator_id"
    t.text "data_source"
    t.string "editable_by", default: "everyone", null: false
    t.string "role"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "updater_id"
    t.index ["cluster_id"], name: "index_wiki_pages_on_cluster_id"
    t.index ["community_id", "slug"], name: "index_wiki_pages_on_community_id_and_slug", unique: true
    t.index ["community_id", "title"], name: "index_wiki_pages_on_community_id_and_title", unique: true
    t.index ["community_id"], name: "index_wiki_pages_on_community_id"
    t.index ["creator_id"], name: "index_wiki_pages_on_creator_id"
    t.index ["updater_id"], name: "index_wiki_pages_on_updater_id"
  end

  create_table "work_assignments", force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.boolean "preassigned", default: false, null: false
    t.integer "shift_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["cluster_id", "shift_id", "user_id"], name: "index_work_assignments_on_cluster_id_and_shift_id_and_user_id"
    t.index ["cluster_id"], name: "index_work_assignments_on_cluster_id"
    t.index ["shift_id"], name: "index_work_assignments_on_shift_id"
    t.index ["user_id"], name: "index_work_assignments_on_user_id"
  end

  create_table "work_jobs", force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.boolean "double_signups_allowed", default: false
    t.decimal "hours", precision: 6, scale: 2, null: false
    t.decimal "hours_per_shift", precision: 6, scale: 2
    t.bigint "meal_role_id"
    t.integer "period_id", null: false
    t.integer "requester_id"
    t.string "slot_type", limit: 32, default: "fixed", null: false
    t.string "time_type", limit: 32, default: "date_time", null: false
    t.string "title", limit: 128, null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_work_jobs_on_cluster_id"
    t.index ["meal_role_id"], name: "index_work_jobs_on_meal_role_id"
    t.index ["period_id", "title"], name: "index_work_jobs_on_period_id_and_title", unique: true
    t.index ["period_id"], name: "index_work_jobs_on_period_id"
    t.index ["requester_id"], name: "index_work_jobs_on_requester_id"
  end

  create_table "work_periods", force: :cascade do |t|
    t.datetime "auto_open_time"
    t.integer "cluster_id", null: false
    t.integer "community_id", null: false
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.integer "max_rounds_per_worker"
    t.string "name", null: false
    t.string "phase", default: "draft", null: false
    t.string "pick_type", default: "free_for_all", null: false
    t.decimal "quota", precision: 10, scale: 2, default: "0.0", null: false
    t.string "quota_type", default: "none", null: false
    t.integer "round_duration"
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.integer "workers_per_round"
    t.index ["cluster_id"], name: "index_work_periods_on_cluster_id"
    t.index ["community_id", "name"], name: "index_work_periods_on_community_id_and_name", unique: true
    t.index ["community_id"], name: "index_work_periods_on_community_id"
    t.index ["starts_on", "ends_on"], name: "index_work_periods_on_starts_on_and_ends_on"
  end

  create_table "work_shares", force: :cascade do |t|
    t.integer "cluster_id", null: false
    t.datetime "created_at", null: false
    t.integer "period_id", null: false
    t.decimal "portion", precision: 4, scale: 3, default: "1.0", null: false
    t.boolean "priority", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["period_id", "user_id"], name: "index_work_shares_on_period_id_and_user_id", unique: true
    t.index ["period_id"], name: "index_work_shares_on_period_id"
    t.index ["user_id"], name: "index_work_shares_on_user_id"
  end

  create_table "work_shifts", force: :cascade do |t|
    t.integer "assignments_count", default: 0, null: false
    t.bigint "cluster_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.integer "job_id", null: false
    t.integer "meal_id"
    t.integer "slots", null: false
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_work_shifts_on_cluster_id"
    t.index ["job_id", "starts_at", "ends_at"], name: "index_work_shifts_on_job_id_and_starts_at_and_ends_at", unique: true
    t.index ["job_id"], name: "index_work_shifts_on_job_id"
    t.index ["meal_id"], name: "index_work_shifts_on_meal_id"
  end

  add_foreign_key "accounts", "clusters"
  add_foreign_key "accounts", "communities"
  add_foreign_key "accounts", "households"
  add_foreign_key "accounts", "statements", column: "last_statement_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "billing_template_member_types", "billing_templates", column: "template_id"
  add_foreign_key "billing_template_member_types", "clusters"
  add_foreign_key "billing_template_member_types", "people_member_types", column: "member_type_id"
  add_foreign_key "billing_templates", "clusters"
  add_foreign_key "billing_templates", "communities"
  add_foreign_key "calendar_events", "calendar_nodes", column: "calendar_id"
  add_foreign_key "calendar_events", "clusters"
  add_foreign_key "calendar_events", "meals"
  add_foreign_key "calendar_events", "users", column: "creator_id"
  add_foreign_key "calendar_events", "users", column: "sponsor_id"
  add_foreign_key "calendar_guideline_inclusions", "calendar_nodes", column: "calendar_id"
  add_foreign_key "calendar_guideline_inclusions", "calendar_shared_guidelines", column: "shared_guidelines_id"
  add_foreign_key "calendar_guideline_inclusions", "clusters"
  add_foreign_key "calendar_nodes", "calendar_nodes", column: "group_id"
  add_foreign_key "calendar_nodes", "clusters"
  add_foreign_key "calendar_nodes", "communities"
  add_foreign_key "calendar_protocolings", "calendar_nodes", column: "calendar_id"
  add_foreign_key "calendar_protocolings", "calendar_protocols", column: "protocol_id"
  add_foreign_key "calendar_protocolings", "clusters"
  add_foreign_key "calendar_protocols", "clusters"
  add_foreign_key "calendar_protocols", "communities"
  add_foreign_key "calendar_shared_guidelines", "clusters"
  add_foreign_key "calendar_shared_guidelines", "communities"
  add_foreign_key "communities", "clusters"
  add_foreign_key "domain_ownerships", "clusters"
  add_foreign_key "domain_ownerships", "communities"
  add_foreign_key "domain_ownerships", "domains"
  add_foreign_key "domains", "clusters"
  add_foreign_key "gdrive_configs", "clusters"
  add_foreign_key "gdrive_configs", "communities"
  add_foreign_key "gdrive_stray_files", "clusters"
  add_foreign_key "gdrive_stray_files", "communities"
  add_foreign_key "group_affiliations", "clusters"
  add_foreign_key "group_affiliations", "communities"
  add_foreign_key "group_affiliations", "groups"
  add_foreign_key "group_mailman_lists", "clusters"
  add_foreign_key "group_mailman_lists", "domains"
  add_foreign_key "group_mailman_lists", "groups"
  add_foreign_key "group_mailman_users", "clusters"
  add_foreign_key "group_mailman_users", "users"
  add_foreign_key "group_memberships", "clusters"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "groups", "clusters"
  add_foreign_key "households", "clusters"
  add_foreign_key "households", "communities"
  add_foreign_key "households", "people_member_types", column: "member_type_id"
  add_foreign_key "meal_assignments", "clusters"
  add_foreign_key "meal_assignments", "meal_roles", column: "role_id"
  add_foreign_key "meal_assignments", "meals"
  add_foreign_key "meal_assignments", "users"
  add_foreign_key "meal_cost_parts", "clusters"
  add_foreign_key "meal_cost_parts", "meal_costs", column: "cost_id"
  add_foreign_key "meal_cost_parts", "meal_types", column: "type_id"
  add_foreign_key "meal_costs", "clusters"
  add_foreign_key "meal_costs", "meals"
  add_foreign_key "meal_costs", "users", column: "reimbursee_id"
  add_foreign_key "meal_formula_parts", "clusters"
  add_foreign_key "meal_formula_parts", "meal_formulas", column: "formula_id"
  add_foreign_key "meal_formula_parts", "meal_types", column: "type_id"
  add_foreign_key "meal_formula_roles", "clusters"
  add_foreign_key "meal_formula_roles", "meal_formulas", column: "formula_id"
  add_foreign_key "meal_formula_roles", "meal_roles", column: "role_id"
  add_foreign_key "meal_formulas", "clusters"
  add_foreign_key "meal_formulas", "communities"
  add_foreign_key "meal_imports", "clusters"
  add_foreign_key "meal_imports", "communities"
  add_foreign_key "meal_imports", "users"
  add_foreign_key "meal_invitations", "clusters"
  add_foreign_key "meal_invitations", "communities"
  add_foreign_key "meal_invitations", "meals"
  add_foreign_key "meal_resourcings", "calendar_nodes", column: "calendar_id"
  add_foreign_key "meal_resourcings", "clusters"
  add_foreign_key "meal_resourcings", "meals"
  add_foreign_key "meal_roles", "clusters"
  add_foreign_key "meal_roles", "communities"
  add_foreign_key "meal_signup_parts", "clusters"
  add_foreign_key "meal_signup_parts", "meal_signups", column: "signup_id"
  add_foreign_key "meal_signup_parts", "meal_types", column: "type_id"
  add_foreign_key "meal_signups", "clusters"
  add_foreign_key "meal_signups", "households"
  add_foreign_key "meal_signups", "meals"
  add_foreign_key "meal_types", "clusters"
  add_foreign_key "meal_types", "communities"
  add_foreign_key "meals", "clusters"
  add_foreign_key "meals", "communities"
  add_foreign_key "meals", "meal_formulas", column: "formula_id"
  add_foreign_key "meals", "users", column: "creator_id"
  add_foreign_key "people_emergency_contacts", "clusters"
  add_foreign_key "people_emergency_contacts", "households"
  add_foreign_key "people_guardianships", "clusters"
  add_foreign_key "people_guardianships", "users", column: "child_id"
  add_foreign_key "people_guardianships", "users", column: "guardian_id"
  add_foreign_key "people_member_types", "clusters"
  add_foreign_key "people_member_types", "communities"
  add_foreign_key "people_memorial_messages", "people_memorials", column: "memorial_id"
  add_foreign_key "people_memorial_messages", "users", column: "author_id"
  add_foreign_key "people_memorials", "clusters"
  add_foreign_key "people_memorials", "users"
  add_foreign_key "people_pets", "clusters"
  add_foreign_key "people_pets", "households"
  add_foreign_key "people_vehicles", "clusters"
  add_foreign_key "people_vehicles", "households"
  add_foreign_key "reminder_deliveries", "clusters"
  add_foreign_key "reminder_deliveries", "meals"
  add_foreign_key "reminder_deliveries", "reminders"
  add_foreign_key "reminder_deliveries", "work_shifts", column: "shift_id"
  add_foreign_key "reminders", "clusters"
  add_foreign_key "reminders", "meal_roles", column: "role_id"
  add_foreign_key "reminders", "work_jobs", column: "job_id"
  add_foreign_key "statements", "accounts"
  add_foreign_key "statements", "clusters"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "clusters"
  add_foreign_key "transactions", "statements"
  add_foreign_key "users", "clusters"
  add_foreign_key "users", "households"
  add_foreign_key "users", "users", column: "job_choosing_proxy_id"
  add_foreign_key "users_roles", "roles"
  add_foreign_key "users_roles", "users"
  add_foreign_key "wiki_page_versions", "clusters"
  add_foreign_key "wiki_page_versions", "users", column: "updater_id"
  add_foreign_key "wiki_page_versions", "wiki_pages", column: "page_id"
  add_foreign_key "wiki_pages", "clusters"
  add_foreign_key "wiki_pages", "communities"
  add_foreign_key "wiki_pages", "users", column: "creator_id"
  add_foreign_key "wiki_pages", "users", column: "updater_id"
  add_foreign_key "work_assignments", "clusters"
  add_foreign_key "work_assignments", "users"
  add_foreign_key "work_assignments", "work_shifts", column: "shift_id"
  add_foreign_key "work_jobs", "clusters"
  add_foreign_key "work_jobs", "groups", column: "requester_id"
  add_foreign_key "work_jobs", "meal_roles"
  add_foreign_key "work_jobs", "work_periods", column: "period_id"
  add_foreign_key "work_periods", "clusters"
  add_foreign_key "work_periods", "communities"
  add_foreign_key "work_shares", "clusters"
  add_foreign_key "work_shares", "users"
  add_foreign_key "work_shares", "work_periods", column: "period_id"
  add_foreign_key "work_shifts", "clusters"
  add_foreign_key "work_shifts", "meals"
  add_foreign_key "work_shifts", "work_jobs", column: "job_id"
end
