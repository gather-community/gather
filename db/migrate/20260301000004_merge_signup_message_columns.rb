# frozen_string_literal: true

class MergeSignupMessageColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :community_signups, :message, :text
    remove_column :community_signups, :approval_message, :text
    remove_column :community_signups, :denial_reason, :text
  end
end
