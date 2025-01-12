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
      has_many :folder_maps, class_name: "GDrive::Migration::FolderMap",
        inverse_of: :operation, dependent: :destroy
      has_many :logs, class_name: "GDrive::Migration::Log",
        inverse_of: :operation, dependent: :destroy

      scope :in_community, ->(c) { joins(:config).where(gdrive_configs: {community_id: c.id}) }
      scope :active, -> { all }

      delegate :community, :community_id, to: :config

      def webhook_registered?
        webhook_channel_id.present?
      end

      def src_folder_url
        "https://drive.google.com/drive/u/0/folders/#{src_folder_id}"
      end

      def log(level, message, data = nil)
        logs.create!(level: level, message: message, data: data)
        data ||= {}
        data["operation_id"] = id
        Rails.logger.send(level, message, **data)
      end
    end
  end
end
