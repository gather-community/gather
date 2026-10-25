# frozen_string_literal: true

class AllowLedgerMessagingTransactions < ActiveRecord::Migration[8.1]
  # Topup credits can now flip credit -> claw-back -> re-credit over an invoice's payment lifecycle,
  # so a line item can have multiple transactions. Drop the unique index (idempotency is now
  # state-based: we reconcile the line's net to its target) and add a non-unique index plus a
  # stripe_event_id for tracing which webhook produced each row.
  def change
    remove_index :messaging_transactions, column: :stripe_invoice_line_item_id, unique: true
    add_index :messaging_transactions, :stripe_invoice_line_item_id
    add_column :messaging_transactions, :stripe_event_id, :string
    add_index :messaging_transactions, :stripe_event_id
  end
end
