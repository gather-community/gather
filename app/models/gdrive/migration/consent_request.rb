# frozen_string_literal: true

module GDrive
  module Migration
    class ConsentRequest < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :consent_requests

      before_create :generate_token

      def clear_ingest
        update!(ingest_requested_at: nil, ingest_file_ids: nil, ingest_status: nil)
      end

      def ingest_done?
        ingest_status == "done"
      end

      def ingest_pending?
        ingest_status == "new" || ingest_status == "in_progress"
      end

      def ingest_failed?
        ingest_status == "failed"
      end

      def ingest_overdue?
        ingest_pending? && ingest_requested_at < Time.current - 5.minutes
      end

      def set_ingest_failed
        update!(status: "ingest_failed", ingest_status: "failed")
      end

      private

      def generate_token
        self.token = SecureRandom.base58(16)
      end
    end
  end
end
