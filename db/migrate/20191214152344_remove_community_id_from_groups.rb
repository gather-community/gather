# frozen_string_literal: true

class RemoveCommunityIdFromGroups < ActiveRecord::Migration[6.0]
  def up
    remove_column(:groups, :community_id)
  end
end
