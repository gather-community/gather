# frozen_string_literal: true

class AddCanRequestJobsToGroups < ActiveRecord::Migration[6.0]
  def change
    # Set default to true for existing rows, then change to false
    add_column :people_groups, :can_request_jobs, :boolean, null: false, default: true
    change_column_default :people_groups, :can_request_jobs, :false
  end
end
