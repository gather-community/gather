# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_requests
#
#  id                   :bigint           not null, primary key
#  cluster_id           :bigint           not null
#  created_at           :datetime         not null
#  error_count          :integer          default(0), not null
#  expired_at           :datetime
#  file_count           :integer          not null
#  file_drop_drive_id   :string(128)
#  file_drop_drive_name :string(128)
#  google_email         :string(255)      not null
#  operation_id         :bigint           not null
#  opt_out_reason       :text
#  status               :string(16)       default("new"), not null
#  token                :string           not null
#  updated_at           :datetime         not null
#
module GDrive
  module Migration
    class Request < ApplicationRecord
      # A request's link stops working this long after it's sent, and its file drop drive is removed.
      EXPIRES_AFTER = 30.days

      acts_as_tenant :cluster

      # Requests old enough to expire that haven't been cleaned up yet.
      scope :due_to_expire, -> { where(expired_at: nil).where(created_at: ...EXPIRES_AFTER.ago) }

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :requests

      before_create :generate_token

      delegate :config, to: :operation

      def active?
        (new? || opened?) && !expired?
      end

      # True as soon as the link is old enough, even before the nightly job has cleaned up.
      def expired?
        expired_at.present? || created_at < EXPIRES_AFTER.ago
      end

      def new?
        status == "new"
      end

      def opened?
        status == "opened"
      end

      def opted_out?
        status == "opted_out"
      end

      private

      def generate_token
        self.token = SecureRandom.base58(16)
      end
    end
  end
end
