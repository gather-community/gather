# frozen_string_literal: true

module GDrive
  module Migration
    class Operation < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :community, inverse_of: :gdrive_migration_operation
      has_many :scans, class_name: "GDrive::Migration::Scan",
        inverse_of: :operation, dependent: :destroy
      has_many :files, class_name: "GDrive::Migration::File",
        inverse_of: :operation, dependent: :destroy
      has_many :requests, class_name: "GDrive::Migration::Request",
        inverse_of: :operation, dependent: :destroy
      has_many :folder_maps, class_name: "GDrive::Migration::FolderMap",
        inverse_of: :operation, dependent: :destroy
      has_many :logs, class_name: "GDrive::Migration::Log",
        inverse_of: :operation, dependent: :destroy

      scope :in_community, ->(c) { where(community_id: c.id) }
      scope :active, -> { all }

      validates :contact_name, presence: true
      validates :contact_email, presence: true, format: Devise.email_regexp
      validates :src_folder_id, presence: true, length: {minimum: 30, maximum: 60},
        format:  /\A[a-z0-9_\-]+\z/i
      validates :dest_folder_id, presence: true, length: {minimum: 19, maximum: 60},
        format:  /\A[a-z0-9_\-]+\z/i

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
