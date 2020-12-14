# frozen_string_literal: true

class RenameInitBalToInitCrd < ActiveRecord::Migration[6.0]
  def up
    execute("UPDATE transactions SET code = 'initcrd' WHERE code = 'initbal'")
  end
end
