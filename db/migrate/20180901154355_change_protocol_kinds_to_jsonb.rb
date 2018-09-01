# frozen_string_literal: true

class ChangeProtocolKindsToJsonb < ActiveRecord::Migration[5.1]
  def up
    add_column :reservation_protocols, :kinds_tmp, :jsonb
    execute("UPDATE reservation_protocols SET kinds_tmp = kinds::jsonb")
    remove_column :reservation_protocols, :kinds
    rename_column :reservation_protocols, :kinds_tmp, :kinds
  end
end
