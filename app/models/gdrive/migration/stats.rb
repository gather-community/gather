# frozen_string_literal: true

module GDrive
  module Migration
    class Stats
      include ActiveModel::Model

      attr_accessor :operation
      attr_reader :total, :by_status, :by_owner, :by_owner_and_status, :owners, :requests_by_owner

      def initialize(...)
        super(...)

        base_query = GDrive::Migration::File.where(operation: operation)
        @total = base_query.count
        @by_status = base_query.group(:status).count
        @by_owner = base_query.group(:owner).count
        @by_owner_and_status = base_query.group(:owner, :status).count
        @owners = base_query.order(:owner).distinct.pluck(:owner)

        # If there are multiple requests for one owner, this will result in the latest one.
        @requests_by_owner = operation.requests.order(:created_at).index_by(&:google_email)
      end
    end
  end
end
