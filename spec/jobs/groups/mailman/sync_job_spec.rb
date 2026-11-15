# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::SyncJob do
  include ActiveJob::TestHelper

  let(:job_class) do
    Class.new(described_class) do
      def self.name
        "MailmanSyncJobSpecJob"
      end

      def perform(error_class)
        error = if error_class == "Groups::Mailman::Api::ServerError"
          request = Net::HTTP::Get.new(URI("https://mailman.example.com/3.1/users"))
          response = Struct.new(:code, :body).new("502", "Bad Gateway")
          error_class.constantize.new(request: request, response: response)
        else
          error_class.constantize.new("boom")
        end
        raise error
      end
    end
  end

  %w[Groups::Mailman::Api::ServerError Net::ReadTimeout Net::OpenTimeout Errno::ECONNREFUSED].each do |klass|
    it "schedules a retry on #{klass}" do
      expect(Gather::ErrorReporter.instance).not_to receive(:report)
      expect { job_class.perform_now(klass) }.to have_enqueued_job(job_class).with(klass)
    end
  end

  it "doesn't retry other errors" do
    expect do
      expect { job_class.perform_now("ArgumentError") }.to raise_error(ArgumentError)
    end.not_to have_enqueued_job
  end
end
