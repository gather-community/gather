# frozen_string_literal: true

# A meal import runs in a background job, but its dates are read, and its errors written, in the language of
# the person who uploaded the file. Earlier imports get English, which is what they ran in.
class AddLocaleToMealImports < ActiveRecord::Migration[8.1]
  def up
    add_column :meal_imports, :locale, :string, limit: 10
    execute("UPDATE meal_imports SET locale = 'en'")
    change_column_null :meal_imports, :locale, false
  end

  def down
    remove_column :meal_imports, :locale
  end
end
