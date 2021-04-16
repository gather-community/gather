# frozen_string_literal: true

class AddColorToCalendarNodes < ActiveRecord::Migration[6.0]
  def change
    add_column :calendar_nodes, :color, :string, limit: 7
  end
end
