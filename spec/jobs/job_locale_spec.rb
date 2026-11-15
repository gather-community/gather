# frozen_string_literal: true

require "rails_helper"

describe ApplicationJob do
  include ActiveJob::TestHelper

  let(:job_class) do
    Class.new(described_class) do
      cattr_accessor :locale_seen

      def perform
        self.class.locale_seen = I18n.locale
      end
    end
  end

  before do
    stub_const("LocaleReportingJob", job_class)
  end

  # ActiveJob restores the locale that was active at enqueue time, i.e. the requester's browser language.
  it "runs in the default locale regardless of the locale it was enqueued under" do
    I18n.with_locale(:fr) { LocaleReportingJob.perform_later }
    perform_enqueued_jobs(only: LocaleReportingJob)
    expect(LocaleReportingJob.locale_seen).to eq(:en)
  end
end
