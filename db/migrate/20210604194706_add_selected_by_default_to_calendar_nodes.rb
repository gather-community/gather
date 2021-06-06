# frozen_string_literal: true

class AddSelectedByDefaultToCalendarNodes < ActiveRecord::Migration[6.0]
  def change
    add_column :calendar_nodes, :selected_by_default, :boolean, null: false, default: false
  end
end
