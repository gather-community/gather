# frozen_string_literal: true

module GDrive
  module Migration
    # Stores a record of a file being migrated
    class File < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :files

      scope :pending, -> { where(status: "pending") }
      scope :transferred, -> { where(status: "transferred") }
      scope :copied, -> { where(status: "copied") }
      scope :declined, -> { where(status: "declined") }
      scope :errored, -> { where(status: "errored") }

      def folder?
        mime_type == GDrive::FOLDER_MIME_TYPE
      end
    end
  end
end
