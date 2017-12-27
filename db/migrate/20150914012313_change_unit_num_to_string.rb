class ChangeUnitNumToString < ActiveRecord::Migration[4.2]
  def change
    change_column :households, :unit_num, :string
  end
end
