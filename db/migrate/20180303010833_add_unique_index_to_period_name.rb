# frozen_string_literal: true

class AddUniqueIndexToPeriodName < ActiveRecord::Migration[5.1]
  def change
    add_index :work_periods, %i[community_id name], unique: true
  end
end
