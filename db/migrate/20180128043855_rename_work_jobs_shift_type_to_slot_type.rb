# frozen_string_literal: true

class RenameWorkJobsShiftTypeToSlotType < ActiveRecord::Migration[5.1]
  def change
    rename_column :work_jobs, :shift_type, :slot_type
  end
end
