# frozen_string_literal: true

class AddAllowOverlapToCalendars < ActiveRecord::Migration[6.0]
  def change
    add_column :calendar_nodes, :allow_overlap, :boolean, null: false, default: true
    reversible do |dir|
      dir.up do
        execute("UPDATE calendar_nodes SET allow_overlap = 'f'")
      end
    end
  end
end
