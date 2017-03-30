require 'rails_helper'

describe Billing::StatementReminderJob do
  describe "perform" do
    before { Timecop.freeze(Time.zone.now.midnight + Settings.reminders.time_of_day.hours) }
    after { Timecop.return }

    it "should send no emails if no statements" do
      expect do
        Billing::StatementReminderJob.new.perform
      end.to change{ActionMailer::Base.deliveries.size}.by(0)
    end

    context "some matching statements" do
      let!(:s1){ create(:statement, due_on: Date.today + 3.days) }
      let!(:s2){ create(:statement, due_on: Date.today + 4.days) }

      it "should send two reminders the first time, then none the second time" do
        [2, 0].each do |count|
          expect do
            Billing::StatementReminderJob.new.perform
          end.to change{ActionMailer::Base.deliveries.size}.by(count)
        end
      end
    end
  end

  describe "remindable_statements" do
    let!(:s1){ create(:statement, due_on: Date.today + 3.days) }
    let!(:s2){ create(:statement, due_on: Date.today + 4.days) }
    let!(:s3){ create(:statement, due_on: Date.today + 7.days) }

    # Should not send if zero or negative balance due.
    let!(:s4){ create(:statement, due_on: Date.today + 3.days, total_due: -1) }
    let!(:s5){ create(:statement, due_on: Date.today + 3.days, total_due: 0) }

    # Should not send if account has a later statement that is not remindable.
    Timecop.freeze(-1.day) do
      let!(:s6){ create(:statement, due_on: Date.today + 3.days) }
    end
    let!(:s7){ create(:statement, account: s6.account, due_on: Date.today + 7.days) }

    it "should select the right statements" do
      expect(Billing::StatementReminderJob.new.send(:remindable_statements).map(&:id)).to eq [s1, s2].map(&:id)
    end
  end
end
