# frozen_string_literal: true

class AddQuotaTypeToWorkPeriods < ActiveRecord::Migration[5.1]
  def change
    add_column :work_periods, :quota_type, :string, null: false, default: "none"
  end
end
