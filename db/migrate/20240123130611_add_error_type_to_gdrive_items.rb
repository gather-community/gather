# frozen_string_literal: true

class AddErrorTypeToGDriveItems < ActiveRecord::Migration[7.0]
  def change
    add_column :gdrive_items, :error_type, :string
    add_check_constraint :gdrive_items, "error_type IN ('inaccessible','not_shareable')",
                         name: :error_type_enum
  end
end
