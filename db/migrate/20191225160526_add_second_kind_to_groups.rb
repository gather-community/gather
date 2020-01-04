# frozen_string_literal: true

class AddSecondKindToGroups < ActiveRecord::Migration[6.0]
  def change
    rename_column :groups, :kind, :availability
    add_column :groups, :kind, :string, limit: 32, null: false, default: "committee"
  end
end
