# frozen_string_literal: true

class ChangeOldIdToInteger < ActiveRecord::Migration[4.2]
  def change
    change_column :households, :old_id, :integer
  end
end
