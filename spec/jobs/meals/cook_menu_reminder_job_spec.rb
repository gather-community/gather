require 'rails_helper'

describe Meals::CookMenuReminderJob do
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let!(:meal1) { create(:meal, meal1_traits, head_cook: user1, served_at: Time.now + 4.days) }
  let!(:meal2) { create(:meal, meal2_traits, head_cook: user2, served_at: Time.now + 9.days) }
  let!(:decoy) { create(:meal, head_cook: user2, cleaners: [user1], served_at: Time.now + 13.days) }
  subject { mails_sent }

  around do |example|
    Timecop.freeze(Time.zone.now.midnight + hour.hours) do
      example.run
    end
  end

  context "at correct hour" do
    let(:hour) { Settings.reminders.time_of_day }

    context "both meals without menus" do
      let(:meal1_traits) { nil }
      let(:meal2_traits) { nil }

      it "should send to both meals" do
        expect(subject.map(&:to)).to contain_exactly([meal1.head_cook.email], [meal2.head_cook.email])
        expect(subject.first.subject).to match(/\AMenu Reminder: Please Post Menu/)
      end

      context "with early reminders already sent for both meals" do
        before do
          meal1.head_cook_assign.update_attribute(:reminder_count, 1)
          meal2.head_cook_assign.update_attribute(:reminder_count, 1)
        end

        it "should send to sooner meal only" do
          expect(subject.map(&:to)).to contain_exactly([meal1.head_cook.email])
        end
      end
    end

    context "menu for sooner meal only" do
      let(:meal1_traits) { :with_menu }
      let(:meal2_traits) { nil }

      it "should send to later meal only" do
        expect(subject.map(&:to)).to contain_exactly([meal2.head_cook.email])
      end
    end

    context "both meals with menus" do
      let(:meal1_traits) { :with_menu }
      let(:meal2_traits) { :with_menu }

      it "should send to neither meal" do
        expect(subject).to be_empty
      end
    end
  end

  context "at incorrect hour" do
    let(:hour) { Settings.reminders.time_of_day + 2 }
    let(:meal1_traits) { nil }
    let(:meal2_traits) { nil }

    it "should send to neither meal" do
      expect(subject).to be_empty
    end
  end

  def mails_sent
    old_count = ActionMailer::Base.deliveries.size
    Meals::CookMenuReminderJob.new.perform
    ActionMailer::Base.deliveries[old_count..-1] || []
  end
end
