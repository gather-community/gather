class AddCreditCols < ActiveRecord::Migration
  def change
    add_column :households, :credit_limit, :integer, null: false, default: 50
    add_column :households, :over_limit, :boolean, null: false, default: false
  end
end
