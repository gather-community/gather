# frozen_string_literal: true

class ChangeCommunitySignupsSlugLimit < ActiveRecord::Migration[7.0]
  def change
    change_column :community_signups, :slug, :string, limit: 20, null: false
  end
end
