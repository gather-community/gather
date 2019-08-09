# frozen_string_literal: true

class AddPriorityToWorkShares < ActiveRecord::Migration[5.1]
  def change
    add_column :work_shares, :priority, :boolean, null: false, default: false
  end
end
