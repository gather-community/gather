class RenameWorkJobsTimesToTimeType < ActiveRecord::Migration[5.1]
  def change
    rename_column :work_jobs, :times, :time_type
  end
end
