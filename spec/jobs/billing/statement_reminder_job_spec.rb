# frozen_string_literal: true

require "rails_helper"

describe Billing::StatementReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  it "should send no emails if no statements" do
    expect(AccountMailer).not_to receive(:statement_reminder)
    perform_job
  end

  context "some matching statements" do
    let!(:s1) { create(:statement, due_on: "2017-01-04") }
    let!(:s2) { create(:statement, due_on: "2017-01-05") }
    let!(:s3) { create(:statement, due_on: "2017-01-08") }

    # Should not send if zero or negative balance due.
    let!(:s4) { create(:statement, due_on: "2017-01-04", total_due: -1) }
    let!(:s5) { create(:statement, due_on: "2017-01-04", total_due: 0) }

    # Should not send if no due date.
    let!(:s6) { create(:statement, due_on: nil) }

    # Should not send if account has a later statement that is not remindable.
    Timecop.freeze(-1.day) do
      let!(:s7) { create(:statement, due_on: "2017-01-04") }
    end
    let!(:s8) { create(:statement, account: s7.account, due_on: "2017-01-08") }

    it "should send two reminders the first time, then none the second time" do
      expect(AccountMailer).to receive(:statement_reminder).exactly(2).times.and_return(mlrdbl)
      perform_job
      expect(AccountMailer).not_to receive(:statement_reminder)
      perform_job
    end

    it "should send the right statements" do
      expect(AccountMailer).to receive(:statement_reminder).with(s1).and_return(mlrdbl)
      expect(AccountMailer).to receive(:statement_reminder).with(s2).and_return(mlrdbl)
      perform_job
    end
  end
end
