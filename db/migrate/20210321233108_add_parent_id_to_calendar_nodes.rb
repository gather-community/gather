# frozen_string_literal: true

class AddParentIdToCalendarNodes < ActiveRecord::Migration[6.0]
  def change
    add_reference :calendar_nodes, :group, index: true, foreign_key: {to_table: :calendar_nodes}
  end
end
