# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_requests
#
#  id                   :bigint           not null, primary key
#  cluster_id           :bigint           not null
#  created_at           :datetime         not null
#  error_count          :integer          default(0), not null
#  file_count           :integer          not null
#  google_email         :string(255)      not null
#  operation_id         :bigint           not null
#  opt_out_reason       :text
#  status               :string(16)       default("new"), not null
#  token                :string           not null
#  updated_at           :datetime         not null
#  file_drop_drive_id   :string(128)
#  file_drop_drive_name :string(128)
#
module GDrive
  module Migration
    class Request < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :requests

      before_create :generate_token

      delegate :config, to: :operation

      def active?
        new? || opened?
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
