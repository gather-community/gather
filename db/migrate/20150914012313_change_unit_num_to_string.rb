class ChangeUnitNumToString < ActiveRecord::Migration
  def change
    change_column :households, :unit_num, :string
  end
end
