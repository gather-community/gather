# frozen_string_literal: true

class RenameJobTemplateColumns < ActiveRecord::Migration[5.1]
  def change
    rename_column :work_job_templates, :meal, :meal_related
    rename_column :work_job_templates, :shift_start_offset, :shift_start
    rename_column :work_job_templates, :shift_end_offset, :shift_end
  end
end
