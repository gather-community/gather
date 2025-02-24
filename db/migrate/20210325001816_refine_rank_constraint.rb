# frozen_string_literal: true

class RefineRankConstraint < ActiveRecord::Migration[6.0]
  def change
    change_column_null :calendar_nodes, :rank, true
    reversible do |dir|
      dir.up do
        execute("UPDATE calendar_nodes SET rank = NULL WHERE deactivated_at IS NOT NULL")
      end
    end
    add_check_constraint :calendar_nodes, "(deactivated_at IS NOT NULL AND rank IS NULL) " \
                                          "OR (rank IS NOT NULL AND deactivated_at IS NULL)", name: "rank_or_deactivated_at_null"
  end
end
