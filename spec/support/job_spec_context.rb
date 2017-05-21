shared_context "jobs" do
  let(:mlrdbl) { double(deliver_now: nil) }

  def perform_job(*args)
    ActsAsTenant.with_tenant(nil) do
      described_class.new(*args).perform
    end
  end
end

shared_context "reminder jobs" do
  around do |example|
    Timecop.freeze(Time.zone.parse("2017-01-01 00:00") + Settings.reminders.time_of_day.hours) do
      example.run
    end
  end
end
