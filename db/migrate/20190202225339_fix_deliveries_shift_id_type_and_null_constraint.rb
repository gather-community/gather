# frozen_string_literal: true

class FixDeliveriesShiftIdTypeAndNullConstraint < ActiveRecord::Migration[5.1]
  def change
    change_column_null :reminder_deliveries, :shift_id, true
    change_column :reminder_deliveries, :shift_id, :bigint
  end
end
