# frozen_string_literal: true

class RemoveNegativesInTransactionAmounts < ActiveRecord::Migration[6.0]
  def up
    execute("UPDATE transactions SET amount = ABS(amount)")
  end
end
