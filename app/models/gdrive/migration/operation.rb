# frozen_string_literal: true

module GDrive
  module Migration
    class Operation < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :config, class_name: "GDrive::MigrationConfig", inverse_of: :operations
      has_many :scans, class_name: "GDrive::Migration::Scan",
        inverse_of: :operation, dependent: :destroy
      has_many :files, class_name: "GDrive::Migration::File",
        inverse_of: :operation, dependent: :destroy
      has_many :consent_requests, class_name: "GDrive::Migration::ConsentRequest",
        inverse_of: :operation, dependent: :destroy

      def src_folder_url
        "https://drive.google.com/drive/u/0/folders/#{src_folder_id}"
      end

      def filename_suffix
        @filename_suffix ||= "[🚚#{filename_tag}]"
      end
    end
  end
end
