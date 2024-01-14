# frozen_string_literal: true

module GDrive
  module Migration
    # Stores a record of a file being migrated
    class File < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :files

      scope :owned_by, ->(o) { where(owner: o) }
      scope :with_status, ->(s) { where(status: s) }
      scope :pending, -> { where(status: "pending") }
      scope :declined, -> { where(status: "declined") }
      scope :errored, -> { where(status: "errored") }
      scope :transferred, -> { where(status: "transferred") }
      scope :copied, -> { where(status: "copied") }
      scope :ignored, -> { where(status: "ignored") }

      def folder?
        mime_type == GDrive::FOLDER_MIME_TYPE
      end

      def acted_on?
        !pending?
      end

      def errored?
        status == "errored"
      end

      def pending?
        status == "pending"
      end

      def transferred?
        status == "transferred"
      end

      def set_error(type:, message: nil)
        self.error_type = type
        self.error_message = message
        self.status = "errored"
        save!
      end
    end
  end
end
