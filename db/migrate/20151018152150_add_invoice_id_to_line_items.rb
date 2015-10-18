class AddInvoiceIdToLineItems < ActiveRecord::Migration
  def change
    add_reference :line_items, :invoice, foreign_key: true
    add_index :line_items, :invoice_id
  end
end
