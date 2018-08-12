# frozen_string_literal: true

# Flag for implementing auto_open_time.
class AddAutoOpenedToWorkPeriods < ActiveRecord::Migration[5.1]
  def change
    add_column :work_periods, :auto_opened, :boolean, default: false, null: false
  end
end
