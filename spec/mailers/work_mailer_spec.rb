# frozen_string_literal: true

require "rails_helper"

describe WorkMailer do
  describe "shift_reminder" do
    let(:job) { create(:work_job, title: "First Frungler", shift_times: ["2018-01-01 9:00"]) }
    let(:user) { create(:user) }
    let(:assignment) { create(:work_assignment, shift: job.shifts.first) }
    let(:reminder) { create(:work_reminder, job: job, note: note) }
    let(:mail) { described_class.shift_reminder(assignment, reminder).deliver_now }

    context "with no note" do
      let(:note) { nil }

      it "sets the right recipient" do
        expect(mail.to).to eq([assignment.user.email])
      end

      it "renders the subject" do
        expect(mail.subject).to eq("Job Reminder: First Frungler, Mon Jan 01 9:00am–11:00am")
      end

      it "renders the correct times and URL in the body" do
        expect(mail.body.encoded).to match(
          "you are scheduled as 'First Frungler' for Mon Jan 01 9:00am–11:00am."
        )
        expect(mail.body.encoded).to have_correct_shift_url(assignment.shift)
      end
    end

    context "with note" do
      let(:note) { "Do stuff" }

      it "renders the subject" do
        expect(mail.subject).to eq("Job Reminder: First Frungler: Do stuff")
      end

      it "renders the note in the body" do
        expect(mail.body.encoded).to match(/This reminder includes the following note:\n-+\nDo stuff\n-+\n/)
      end
    end
  end
end
