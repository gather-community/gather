# frozen_string_literal: true

# Renames two community signup statuses: "pending" becomes "new", and "approved" becomes "creating"
# (approved, with the community being set up in the background).
class RenameCommunitySignupStatuses < ActiveRecord::Migration[8.1]
  RENAMES = {"pending" => "new", "approved" => "creating"}.freeze

  def up
    change_column_default(:community_signups, :status, from: "pending", to: "new")
    RENAMES.each do |old, new|
      execute("UPDATE community_signups SET status = '#{new}' WHERE status = '#{old}'")
    end
  end

  def down
    change_column_default(:community_signups, :status, from: "new", to: "pending")
    RENAMES.each do |old, new|
      execute("UPDATE community_signups SET status = '#{old}' WHERE status = '#{new}'")
    end
  end
end
