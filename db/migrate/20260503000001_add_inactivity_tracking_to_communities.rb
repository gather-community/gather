# frozen_string_literal: true

class AddInactivityTrackingToCommunities < ActiveRecord::Migration[8.1]
  def change
    add_column :communities, :inactivity_warning_count, :integer, null: false, default: 0
    add_column :communities, :inactivity_warning_sent_at, :datetime
    add_index :communities, :inactivity_warning_count
    add_index :communities, :inactivity_warning_sent_at
  end
end
