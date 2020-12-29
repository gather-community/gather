# frozen_string_literal: true

class RenameTemplatesAmountColumn < ActiveRecord::Migration[6.0]
  def change
    rename_column :billing_templates, :amount, :value
  end
end
