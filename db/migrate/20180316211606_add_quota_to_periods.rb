# frozen_string_literal: true

class AddQuotaToPeriods < ActiveRecord::Migration[5.1]
  def change
    add_column :work_periods, :quota, :decimal, precision: 10, scale: 2, null: false, default: 0
  end
end
