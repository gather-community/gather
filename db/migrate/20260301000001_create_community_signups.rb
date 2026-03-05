# frozen_string_literal: true

class CreateCommunitySignups < ActiveRecord::Migration[7.0]
  def change
    create_table :community_signups do |t|
      t.string :contact_first_name, null: false
      t.string :contact_last_name, null: false
      t.string :contact_email, null: false
      t.string :community_name, limit: 20, null: false
      t.string :slug, limit: 63, null: false
      t.string :country_code, limit: 2, null: false, default: "US"
      t.string :time_zone, null: false, default: "UTC"
      t.text :introduction, null: false
      t.boolean :want_sample_data, null: false, default: false
      t.string :status, null: false, default: "pending"
      t.text :denial_reason
      t.datetime :reviewed_at
      t.bigint :reviewed_by_id

      t.timestamps
    end

    add_index :community_signups, :slug, unique: true
    add_foreign_key :community_signups, :users, column: :reviewed_by_id
  end
end
