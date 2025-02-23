# frozen_string_literal: true

class SetAllergensSettingDefaultValue < ActiveRecord::Migration[5.1]
  def up
    value = "Gluten, Shellfish, Soy, Corn, Dairy, Eggs, Peanuts, Almonds, " \
            "Tree Nuts, Pineapple, Bananas, Tofu, Eggplant"
    execute(%(UPDATE communities SET settings = jsonb_insert(settings, '{meals, allergens}', '"#{value}"')))
  end
end
