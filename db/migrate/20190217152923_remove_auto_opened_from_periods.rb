# frozen_string_literal: true

class RemoveAutoOpenedFromPeriods < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_periods, :auto_opened, :boolean
  end
end
