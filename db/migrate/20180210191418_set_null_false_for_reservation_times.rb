# frozen_string_literal: true

class SetNullFalseForReservationTimes < ActiveRecord::Migration[5.1]
  def change
    change_column_null :reservations, :starts_at, false
    change_column_null :reservations, :ends_at, false
  end
end
