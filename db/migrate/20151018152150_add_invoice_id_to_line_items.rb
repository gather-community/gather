# frozen_string_literal: true

class AddInvoiceIdToLineItems < ActiveRecord::Migration[4.2]
  def change
    add_reference :line_items, :invoice, foreign_key: true
    add_index :line_items, :invoice_id
  end
end
