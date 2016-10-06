class RemovePaymentMethodFromMeals < ActiveRecord::Migration
  def change
    remove_column :meals, :payment_method, :string
  end
end
