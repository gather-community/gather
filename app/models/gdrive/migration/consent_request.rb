# frozen_string_literal: true

module GDrive
  module Migration
    class ConsentRequest < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :consent_requests

      before_create :generate_token

      private

      def generate_token
        self.token = SecureRandom.base58(16)
      end
    end
  end
end
