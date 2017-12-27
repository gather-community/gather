class RemovePaymentMethodFromMeals < ActiveRecord::Migration[4.2]
  def change
    remove_column :meals, :payment_method, :string
  end
end
