# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_files
#
#  id                        :bigint           not null, primary key
#  error_message             :string(255)
#  error_type                :string
#  icon_link                 :string           not null
#  mime_type                 :string(255)      not null
#  modified_at               :datetime         not null
#  name                      :text             not null
#  owner                     :string           not null
#  shortcut_target_mime_type :string(128)
#  status                    :string           not null
#  web_view_link             :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  cluster_id                :bigint           not null
#  external_id               :string           not null
#  operation_id              :bigint           not null
#  parent_id                 :string           not null
#  shortcut_target_id        :string(128)
#
# Indexes
#
#  gdrive_files_on_shortcut                                      (operation_id,shortcut_target_id)
#  index_gdrive_migration_files_on_cluster_id                    (cluster_id)
#  index_gdrive_migration_files_on_operation_id                  (operation_id)
#  index_gdrive_migration_files_on_operation_id_and_external_id  (operation_id,external_id) UNIQUE
#  index_gdrive_migration_files_on_owner                         (operation_id,owner,status)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (operation_id => gdrive_migration_operations.id)
#
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

      def set_error(type:, message: nil)
        self.error_type = type
        self.error_message = message
        self.status = "errored"
        save!
      end
    end
  end
end
