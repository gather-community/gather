# frozen_string_literal: true

class AddLimitsToCommunitySignups < ActiveRecord::Migration[7.0]
  def change
    change_column :community_signups, :contact_first_name, :string, limit: 255, null: false
    change_column :community_signups, :contact_last_name, :string, limit: 255, null: false
    change_column :community_signups, :contact_email, :string, limit: 254, null: false
    change_column :community_signups, :time_zone, :string, limit: 64, null: false, default: "UTC"
    change_column :community_signups, :introduction, :string, limit: 5000, null: false
    change_column :community_signups, :message, :string, limit: 5000
  end
end
