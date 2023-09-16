# frozen_string_literal: true

module GDrive
  module Migration
    class Stats
      include ActiveModel::Model

      attr_accessor :operation
      attr_reader :total, :by_status, :by_owner, :by_owner_and_status, :owners

      def initialize(...)
        super(...)

        base_query = GDrive::Migration::File.where(operation: operation)
        @total = base_query.count
        @by_status = base_query.group(:status).count
        @by_owner = base_query.group(:owner).count
        @by_owner_and_status = base_query.group(:owner, :status).count
        @owners = base_query.order(:owner).distinct.pluck(:owner)
      end
    end
  end
end
