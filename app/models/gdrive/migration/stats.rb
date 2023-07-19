# frozen_string_literal: true

module GDrive
  module Migration
    class Stats
      include ActiveModel::Model

      attr_accessor :operation
      attr_reader :total, :pending, :transferred, :copied, :remaining, :declined, :errored

      def initialize(...)
        super(...)

        @total = operation.files.count
        @pending = operation.files.pending.count
        @transferred = operation.files.transferred.count
        @copied = operation.files.copied.count
        @declined = operation.files.declined.count
        @errored = operation.files.errored.count
      end
    end
  end
end
