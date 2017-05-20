require 'rails_helper'

describe Billing::StatementReminderJob do
  let(:mlrdbl) { double(deliver_now: nil) }

  around do |example|
    Timecop.freeze(Time.zone.parse("2017-01-01 00:00") + Settings.reminders.time_of_day.hours) do
      example.run
    end
  end

  it "should send no emails if no statements" do
    expect(AccountMailer).not_to receive(:statement_reminder)
    described_class.new.perform
  end

  context "some matching statements" do
    let!(:s1) { create(:statement, due_on: "2017-01-04") }
    let!(:s2) { create(:statement, due_on: "2017-01-05") }
    let!(:s3) { create(:statement, due_on: "2017-01-08") }

    # Should not send if zero or negative balance due.
    let!(:s4) { create(:statement, due_on: "2017-01-04", total_due: -1) }
    let!(:s5) { create(:statement, due_on: "2017-01-04", total_due: 0) }

    # Should not send if account has a later statement that is not remindable.
    Timecop.freeze(-1.day) do
      let!(:s6) { create(:statement, due_on: "2017-01-04") }
    end
    let!(:s7) { create(:statement, account: s6.account, due_on: "2017-01-08") }

    it "should send two reminders the first time, then none the second time" do
      expect(AccountMailer).to receive(:statement_reminder).exactly(2).times.and_return(mlrdbl)
      described_class.new.perform
      expect(AccountMailer).not_to receive(:statement_reminder)
      described_class.new.perform
    end

    it "should send the right statements" do
      expect(AccountMailer).to receive(:statement_reminder).with(s1).and_return(mlrdbl)
      expect(AccountMailer).to receive(:statement_reminder).with(s2).and_return(mlrdbl)
      described_class.new.perform
    end
  end
end
