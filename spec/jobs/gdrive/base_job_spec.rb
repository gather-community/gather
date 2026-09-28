# frozen_string_literal: true

require "rails_helper"

describe GDrive::BaseJob do
  include ActiveJob::TestHelper

  let(:job_class) do
    Class.new(described_class) do
      def self.name
        "GDriveBaseJobSpecJob"
      end

      def perform(error_class)
        raise error_class.constantize.new("boom")
      end
    end
  end

  %w[Google::Apis::ServerError GDrive::Wrapper::RateLimitError].each do |error_class|
    it "schedules a retry on #{error_class}" do
      expect { job_class.perform_now(error_class) }.to have_enqueued_job(job_class).with(error_class)
    end
  end
end
