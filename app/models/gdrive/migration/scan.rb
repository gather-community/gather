# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_scans
#
#  id                 :bigint           not null, primary key
#  cancel_reason      :string(128)
#  error_count        :integer          default(0), not null
#  scanned_file_count :integer          default(0), not null
#  scope              :string(16)       default("full"), not null
#  status             :string(32)       default("new"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  cluster_id         :bigint           not null
#  operation_id       :bigint           not null
#
# Indexes
#
#  index_gdrive_migration_scans_on_cluster_id    (cluster_id)
#  index_gdrive_migration_scans_on_operation_id  (operation_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (operation_id => gdrive_migration_operations.id)
#
module GDrive
  module Migration
    # Models a single scan attempt, whether it be a user-initiated full scan
    # or a delta scan caused by a webhook hit.
    class Scan < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, inverse_of: :scans
      has_many :scan_tasks, inverse_of: :scan, dependent: :destroy

      scope :full, -> { where(scope: "full") }
      scope :changes, -> { where(scope: "changes") }
      scope :pending, -> { where(status: %w[new in_progress]) }

      def new?
        status == "new"
      end

      def cancelled?
        status == "cancelled"
      end

      def in_progress?
        status == "in_progress"
      end

      def complete?
        status == "complete"
      end

      def full?
        scope == "full"
      end

      def changes?
        scope == "changes"
      end
    end
  end
end
