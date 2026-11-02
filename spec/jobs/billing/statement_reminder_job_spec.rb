# frozen_string_literal: true

require "rails_helper"

describe Billing::StatementReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  before { ActionMailer::Base.deliveries.clear }

  it "should send no emails if no statements" do
    perform_job
    expect(ActionMailer::Base.deliveries).to be_empty
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

    let(:expected_recipients) { [s1, s2].flat_map { |s| s.household.users.map { |u| [u.email] } } }

    it "should send reminders for the right statements the first time, then none the second time" do
      perform_job
      expect(expected_recipients.size).to be >= 2
      expect(ActionMailer::Base.deliveries.map(&:to)).to match_array(expected_recipients)
      expect { perform_job }.not_to(change { ActionMailer::Base.deliveries.size })
    end
  end
end
