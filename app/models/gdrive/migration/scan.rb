# frozen_string_literal: true

module GDrive
  module Migration
    # Models a single scan attempt, whether it be a user-initiated full scan
    # or a delta scan caused by a webhook hit.
    class Scan < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, inverse_of: :scans
      has_many :scan_tasks, inverse_of: :scan, dependent: :destroy

      scope :changes, -> { where(scope: "changes") }

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

      def delta?
        scope == "delta"
      end
    end
  end
end
