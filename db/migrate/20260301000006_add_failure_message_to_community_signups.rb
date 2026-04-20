# frozen_string_literal: true

class AddFailureMessageToCommunitySignups < ActiveRecord::Migration[7.0]
  def change
    add_column :community_signups, :failure_message, :text
  end
end
