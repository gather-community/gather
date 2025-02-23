# frozen_string_literal: true

require "rails_helper"

describe WorkMailer do
  describe "job_reminder" do
    let(:job) { create(:work_job, title: "First Frungler", shift_starts: ["2018-01-01 9:00"]) }
    let(:user) { create(:user) }
    let(:assignment) { create(:work_assignment, shift: job.shifts.first) }
    let(:reminder) { create(:work_job_reminder, job: job, note: note) }
    let(:mail) { described_class.job_reminder(assignment, reminder).deliver_now }

    context "with no note" do
      let(:note) { nil }

      it "sets the right recipient" do
        expect(mail.to).to eq([assignment.user.email])
      end

      it "renders the subject" do
        expect(mail.subject).to eq("Job Reminder: First Frungler, Mon Jan 01 9:00am–11:00am")
      end

      it "renders the correct times and URL in the body" do
        expect(mail.body.encoded).to include(
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
        expect(mail.body.encoded).to match(
          /This reminder includes the following note:\r\n-+\r\nDo stuff\r\n-+/
        )
      end
    end
  end

  describe "job_choosing_notice" do
    let(:user) { create(:user, first_name: "Tom") }
    let(:fc_job) { double(title: "Junk") }
    let(:period) do
      double(id: 123, auto_open_time: Time.zone.parse("2018-08-15 19:00"), staggered?: staggered,
             community: Defaults.community, quota_none?: false)
    end
    let(:synopsis) do
      double(user_regular_got: 5, user_adjusted_quota: 15.5, user_need: 10.5,
             user_full_community_hours: {fc_job => 4}, rounds: rounds)
    end
    let(:share) { double(user: user, period: period) }
    let(:mail) { described_class.job_choosing_notice(share).deliver_now }

    before do
      allow(Work::Synopsis).to receive(:new).and_return(nil)
      allow(Work::SynopsisDecorator).to receive(:new).and_return(synopsis)
    end

    context "staggered" do
      let(:staggered) { true }

      context "single round" do
        let(:rounds) { [{starts_at: period.auto_open_time, limit: 10}] }

        it do
          expect(mail.subject).to eq("Job Choosing is Coming Up!")
          expect(mail.body.encoded).to include("You have 5 pre-assigned hours and your quota is 15.5, " \
                                               "so you need to choose 10.5 regular hours.")
          expect(mail.body.encoded).to include("You are also expected to choose 4 Junk hours.")
          expect(mail.body.encoded).to include("You can begin choosing at 7:00pm.\r\n\r\nGo to")
          expect(mail.body.encoded).to have_correct_shifts_url(Defaults.community)
        end
      end

      context "multiple rounds" do
        let(:rounds) do
          [{starts_at: period.auto_open_time, limit: 10},
           {starts_at: period.auto_open_time + 300, limit: 20}]
        end

        it do
          expect(mail.body.encoded).to include("Your round schedule is as follows:\r\n" \
                                               "* At 7:00pm you can choose up to 10 hours.\r\n" \
                                               "* At 7:05pm you can choose up to 20 hours.")
        end
      end
    end

    context "not staggered" do
      let(:staggered) { false }
      let(:rounds) { [] }

      it { expect(mail.body.encoded).to include("Choosing begins at 7:00pm.") }
    end
  end

  def have_correct_shifts_url(community)
    contain_community_url(community, "/work/signups?period_id=123")
  end

  def have_correct_shift_url(shift)
    contain_community_url(shift.community, "/work/signups/#{shift.id}")
  end
end
