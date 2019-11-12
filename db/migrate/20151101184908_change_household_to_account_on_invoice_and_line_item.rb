# frozen_string_literal: true

class ChangeHouseholdToAccountOnInvoiceAndLineItem < ActiveRecord::Migration[4.2]
  def change
    remove_foreign_key "invoices", "households"
    remove_foreign_key "line_items", "households"
    rename_column :invoices, :household_id, :account_id
    rename_column :line_items, :household_id, :account_id
    add_foreign_key "invoices", "accounts"
    add_foreign_key "line_items", "accounts"
  end
end
