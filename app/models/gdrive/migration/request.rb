# frozen_string_literal: true

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
