class AddHoursPerShiftToWorkJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :work_jobs, :hours_per_shift, :decimal, precision: 6, scale: 2
  end
end
