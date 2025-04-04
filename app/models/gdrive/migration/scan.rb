# frozen_string_literal: true

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
