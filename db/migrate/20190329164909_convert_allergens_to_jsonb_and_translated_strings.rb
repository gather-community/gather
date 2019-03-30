# frozen_string_literal: true

class ConvertAllergensToJsonbAndTranslatedStrings < ActiveRecord::Migration[5.1]
  TRANSLATIONS = {
    gluten: "Gluten",
    shellfish: "Shellfish",
    soy: "Soy",
    corn: "Corn",
    dairy: "Dairy",
    eggs: "Eggs",
    peanuts: "Peanuts",
    almonds: "Almonds",
    tree_nuts: "Tree Nuts",
    pineapple: "Pineapple",
    bananas: "Bananas",
    tofu: "Tofu",
    eggplant: "Eggplant"
  }.freeze

  def up
    rename_column :meals, :allergens, :allergens_old
    add_column :meals, :allergens, :jsonb, default: [], null: false
    execute("SELECT id, allergens_old FROM meals").to_a.each do |row|
      allergens = JSON.parse(row["allergens_old"])
      allergens = (allergens - ["none"]).map { |a| TRANSLATIONS[a.to_sym] }
      execute("UPDATE meals SET allergens = '#{allergens.to_json}' WHERE id = #{row['id']}")
    end
    remove_column :meals, :allergens_old
  end
end
