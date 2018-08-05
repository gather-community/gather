# frozen_string_literal: true

# Fields for staggering/rounds
class AddRoundFieldsToWorkPeriods < ActiveRecord::Migration[5.1]
  def change
    add_column :work_periods, :auto_open_time, :datetime
    add_column :work_periods, :workers_per_round, :integer
    add_column :work_periods, :round_duration, :integer
    add_column :work_periods, :hours_per_round, :integer
  end
end
