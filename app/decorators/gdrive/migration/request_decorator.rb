# frozen_string_literal: true

module GDrive
  module Migration
    class RequestDecorator < ApplicationDecorator
      delegate_all

      def file_drop_drive_url
        "https://drive.google.com/drive/folders/#{file_drop_drive_id}"
      end

      def owned_files_url
        src_folder_id = operation.src_folder_id
        "https://drive.google.com/drive/u/0/search?q=-type:folder%20owner:me%20parent:#{src_folder_id}"
      end
    end
  end
end