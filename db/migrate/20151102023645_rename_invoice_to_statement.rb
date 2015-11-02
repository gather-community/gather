class RenameInvoiceToStatement < ActiveRecord::Migration
  def change
    rename_table :invoices, :statements
    rename_column :accounts, :due_last_invoice, :due_last_statement
    rename_column :accounts, :last_invoiced_on, :last_statement_on
    rename_column :accounts, :last_invoice_id, :last_statement_id
    rename_column :line_items, :invoice_id, :statement_id
    rename_column :line_items, :invoiceable_type, :statementable_type
    rename_column :line_items, :invoiceable_id, :statementable_id
  end
end
