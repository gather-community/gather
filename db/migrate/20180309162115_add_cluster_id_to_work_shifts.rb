class AddClusterIdToWorkShifts < ActiveRecord::Migration[5.1]
  def change
    add_reference :work_shifts, :cluster, index: true, foreign_key: true
    execute("UPDATE work_shifts SET cluster_id = 1")
    change_column_null(:work_shifts, :cluster_id, false)
  end
end
