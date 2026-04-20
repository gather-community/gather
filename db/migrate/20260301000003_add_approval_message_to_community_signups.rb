# frozen_string_literal: true

class AddApprovalMessageToCommunitySignups < ActiveRecord::Migration[7.0]
  def change
    add_column :community_signups, :approval_message, :text
  end
end
