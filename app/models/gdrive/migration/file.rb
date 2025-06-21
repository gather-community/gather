# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_files
#
#  id                        :bigint           not null, primary key
#  cluster_id                :bigint           not null
#  created_at                :datetime         not null
#  error_message             :string(255)
#  error_type                :string
#  external_id               :string           not null
#  icon_link                 :string           not null
#  mime_type                 :string(255)      not null
#  modified_at               :datetime         not null
#  name                      :text             not null
#  operation_id              :bigint           not null
#  owner                     :string           not null
#  parent_id                 :string           not null
#  shortcut_target_id        :string(128)
#  shortcut_target_mime_type :string(128)
#  status                    :string           not null
#  updated_at                :datetime         not null
#  web_view_link             :string           not null
#  migrated_parent_id        :string
#
module GDrive
  module Migration
    # Stores a record of a file being migrated
    class File < ApplicationRecord
      acts_as_tenant :cluster

      FINAL_STATUSES = %w[transferred copied ignored].freeze

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :files

      scope :owned_by, ->(o) { where(owner: o) }
      scope :with_status, ->(s) { where(status: s) }
      scope :pending, -> { where(status: "pending") }
      scope :declined, -> { where(status: "declined") }
      scope :errored, -> { where(status: "errored") }
      scope :transferred, -> { where(status: "transferred") }
      scope :copied, -> { where(status: "copied") }
      scope :ignored, -> { where(status: "ignored") }
      scope :disappeared, -> { where(status: "disappeared") }
      scope :with_final_status, -> { where(status: FINAL_STATUSES) }
      scope :with_non_final_status, -> { where.not(status: FINAL_STATUSES) }

      def folder?
        mime_type == GDrive::FOLDER_MIME_TYPE
      end

      # Whether the has already been sent to the new drive.
      def migrated?
        transferred? && copied?
      end

      def declined?
        status == "declined"
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

      def disappeared?
        status == "disappeared"
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
