# frozen_string_literal: true

class RemovePaperclipCols < ActiveRecord::Migration[6.0]
  def up
    remove_column(:users, :photo_content_type)
    remove_column(:users, :photo_file_name)
    remove_column(:users, :photo_file_size)
    remove_column(:users, :photo_updated_at)
    remove_column(:resources, :photo_content_type)
    remove_column(:resources, :photo_file_name)
    remove_column(:resources, :photo_file_size)
    remove_column(:resources, :photo_updated_at)
  end
end
