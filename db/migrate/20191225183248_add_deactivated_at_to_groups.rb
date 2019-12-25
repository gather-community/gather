# frozen_string_literal: true

class AddDeactivatedAtToGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :deactivated_at, :datetime
  end
end
