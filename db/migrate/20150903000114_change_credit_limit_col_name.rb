# frozen_string_literal: true

class ChangeCreditLimitColName < ActiveRecord::Migration[4.2]
  def change
    rename_column :credit_limits, :limit, :amount
  end
end
