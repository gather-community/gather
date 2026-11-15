# frozen_string_literal: true

# Top-ups are created by the Stripe webhook, which has no reader's language to write a description in. They
# now record what they are in `kind` and are described in the reader's language when shown. Only manual
# transactions, which a person writes, keep a stored description.
class AddKindToMessagingTransactions < ActiveRecord::Migration[8.1]
  KIND_VALID = "kind IN ('topup_credit', 'topup_reversal', 'manual')"
  DESCRIPTION_ONLY_IF_MANUAL = "(kind = 'manual') = (description IS NOT NULL)"

  def up
    add_column :messaging_transactions, :kind, :string, limit: 16
    execute(<<~SQL.squish)
      UPDATE messaging_transactions SET kind = CASE
        WHEN creator_id IS NOT NULL THEN 'manual'
        WHEN amount_cents > 0 THEN 'topup_credit'
        ELSE 'topup_reversal'
      END
    SQL
    change_column_null :messaging_transactions, :kind, false
    change_column_null :messaging_transactions, :description, true
    execute("UPDATE messaging_transactions SET description = NULL WHERE kind <> 'manual'")
    add_check_constraint :messaging_transactions, KIND_VALID, name: "kind_valid"
    add_check_constraint :messaging_transactions, DESCRIPTION_ONLY_IF_MANUAL, name: "description_only_if_manual"
  end

  def down
    remove_check_constraint :messaging_transactions, DESCRIPTION_ONLY_IF_MANUAL, name: "description_only_if_manual"
    remove_check_constraint :messaging_transactions, KIND_VALID, name: "kind_valid"
    execute("UPDATE messaging_transactions SET description = 'Monthly messaging topup' " \
            "WHERE kind = 'topup_credit'")
    execute("UPDATE messaging_transactions SET description = 'Reversal of uncollected messaging topup' " \
            "WHERE kind = 'topup_reversal'")
    change_column_null :messaging_transactions, :description, false
    remove_column :messaging_transactions, :kind
  end
end
