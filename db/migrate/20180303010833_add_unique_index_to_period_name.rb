class AddUniqueIndexToPeriodName < ActiveRecord::Migration[5.1]
  def change
    add_index :work_periods, [:community_id, :name], unique: true
  end
end
