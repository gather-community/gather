# frozen_string_literal: true

class FixStatementableColumn < ActiveRecord::Migration[5.1]
  def up
    execute("UPDATE transactions SET statementable_type = 'Meals::Meal' WHERE statementable_type = 'Meal'")
  end

  def down
    execute("UPDATE transactions SET statementable_type = 'Meal' WHERE statementable_type = 'Meals::meal'")
  end
end
