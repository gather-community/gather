# frozen_string_literal: true

class RenameGroupsMembershipToKind < ActiveRecord::Migration[6.0]
  def change
    rename_column(:groups, :membership, :kind)
  end
end
