# frozen_string_literal: true

class AddUniqueKeyToJobTitle < ActiveRecord::Migration[5.1]
  def change
    add_index :work_jobs, %i[period_id title], unique: true
  end
end
