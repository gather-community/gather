# frozen_string_literal: true

class RenameOldBalToInitBal < ActiveRecord::Migration[6.0]
  def change
    execute("UPDATE transactions SET code = 'initbal' WHERE code = 'oldbal'")
  end
end
