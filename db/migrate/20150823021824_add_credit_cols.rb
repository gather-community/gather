class AddCreditCols < ActiveRecord::Migration
  def change
    unless column_exists?(:households, :credit_limit)
      add_column :households, :credit_limit, :integer, null: false, default: 50
    end
    add_column :households, :over_limit, :boolean, null: false, default: false
  end
end
