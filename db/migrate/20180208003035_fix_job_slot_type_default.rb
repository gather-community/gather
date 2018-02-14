class FixJobSlotTypeDefault < ActiveRecord::Migration[5.1]
  def up
    change_column_default :work_jobs, :slot_type, "fixed"
  end
end
