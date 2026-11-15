# frozen_string_literal: true

module GDrive
  module Migration
    class RequestDecorator < ApplicationDecorator
      delegate_all

      def file_drop_drive_url
        "https://drive.google.com/drive/folders/#{file_drop_drive_id}"
      end

      # The drive's name, linked to it while it still exists. Expired requests' drives are deleted.
      def file_drop_drive_link
        return file_drop_drive_name if file_drop_drive_id.blank?
        h.link_to(file_drop_drive_name, file_drop_drive_url)
      end

      # The status, noting when the link has expired, since that's when the request stops being usable.
      def status_label
        status = I18n.t("gdrive.request_statuses.#{object.status}")
        expired? ? h.t("gdrive.request_status_expired", status: status) : status
      end

      def owned_files_url
        src_folder_id = operation.src_folder_id
        "https://drive.google.com/drive/u/0/search?q=-type:folder%20owner:me%20parent:#{src_folder_id}"
      end
    end
  end
end
