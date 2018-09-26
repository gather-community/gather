# frozen_string_literal: true

# Change of plans, slightly.
class RenameHoursPerRound < ActiveRecord::Migration[5.1]
  def change
    rename_column :work_periods, :hours_per_round, :max_rounds_per_worker
  end
end
