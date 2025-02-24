# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_consent_requests
#
#  id                  :bigint           not null, primary key
#  error_count         :integer          default(0), not null
#  file_count          :integer          not null
#  google_email        :string(255)      not null
#  ingest_file_ids     :jsonb
#  ingest_progress     :integer
#  ingest_requested_at :datetime
#  ingest_status       :string
#  opt_out_reason      :text
#  status              :string(16)       default("new"), not null
#  token               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  cluster_id          :bigint           not null
#  operation_id        :bigint           not null
#  temp_drive_id       :string
#
# Indexes
#
#  index_gdrive_migration_consent_requests_on_cluster_id    (cluster_id)
#  index_gdrive_migration_consent_requests_on_operation_id  (operation_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (operation_id => gdrive_migration_operations.id)
#
module GDrive
  module Migration
    class ConsentRequest < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :consent_requests

      before_create :generate_token

      delegate :config, to: :operation

      def pending?
        status == "new" || status == "in_progress"
      end

      def in_progress?
        status == "in_progress"
      end

      def done?
        status == "done"
      end

      def opted_out?
        status == "opted_out"
      end

      def setup_ingest(file_ids)
        update!(
          ingest_requested_at: Time.current,
          ingest_file_ids: file_ids,
          ingest_status: "new",
          ingest_progress: 0
        )
      end

      def clear_ingest
        update!(ingest_requested_at: nil, ingest_file_ids: nil, ingest_status: nil, ingest_progress: nil)
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
