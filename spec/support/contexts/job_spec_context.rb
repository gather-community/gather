# frozen_string_literal: true

shared_context "jobs" do
  # Mailer double to be returned when stubbing mailer.
  let(:mlrdbl) { double(deliver_now: nil) }

  # We instantiate an instance of the job class instead of using perform_later so that we have
  # a reference on which we can stub things.
  # But this means we're not directly using the serialize/deserialize code of ActiveJob.
  # So we test that separately below.
  subject(:job) { described_class.new }

  # Runs job without tenant to ensure that job sets tenant itself.
  # Does not take any arguments. If job requires arguments, override subject(:job) to instantiate
  # an instance of the job with the desired arguments.
  def perform_job
    ActsAsTenant.without_tenant do
      # Serializing and deserializing to simulate calling perform_later.
      job.deserialize(job.serialize)
      job.perform_now
    end
  end
end

shared_context "reminder jobs" do
  # Sets time to the correct hour for delivering reminders
  around do |example|
    Timecop.freeze(Time.zone.parse("2017-01-01 00:00") + Settings.reminders.time_of_day.hours) do
      example.run
    end
  end
end
