# frozen_string_literal: true

class AddDefaultOwnersModeratorsColumnsToGroups < ActiveRecord::Migration[6.0]
  def change
    add_column(:groups, :can_administer_email_lists, :boolean, default: false, null: false)
    add_column(:groups, :can_moderate_email_lists, :boolean, default: false, null: false)
  end
end
