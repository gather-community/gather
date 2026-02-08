# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_scans
#
#  id                 :bigint           not null, primary key
#  cancel_reason      :string(128)
#  cluster_id         :bigint           not null
#  created_at         :datetime         not null
#  error_count        :integer          default(0), not null
#  log_data           :jsonb
#  operation_id       :bigint           not null
#  scanned_file_count :integer          default(0), not null
#  scope              :string(16)       default("full"), not null
#  status             :string(32)       default("new"), not null
#  updated_at         :datetime         not null
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

      def log(level, message, data = nil)
        data ||= {}
        data.merge!(log_data) if log_data.present?
        data["scan_scope"] = scope
        data["scan_id"] = id
        operation.log(level, message, data)
      end

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
