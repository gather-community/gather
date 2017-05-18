require 'rails_helper'

describe Meals::MealReminderJob do
  let(:c2) { create(:community) }
  let!(:meal1) { create(:meal, :with_menu, title: "Meal 1", served_at: "2017-01-01 18:15") }
  let!(:meal2) { create(:meal, :with_menu, title: "Meal 2", served_at: "2017-01-01 18:15", community: c2) }
  let!(:meal3) { create(:meal, :with_menu, title: "Meal 3", served_at: "2017-01-02 18:15") }
  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:user3) { create(:user, household: user2.household) }
  let!(:user4) { create(:user) }
  let!(:signup1) { create(:signup, household: user1.household, meal: meal1) }
  let!(:signup2) { create(:signup, household: user1.household, meal: meal2) }
  let!(:signup3) { create(:signup, household: user2.household, meal: meal2) }
  let!(:signup4) { create(:signup, household: user2.household, meal: meal3) }
  let!(:signup5) { create(:signup, household: user4.household, meal: meal1, notified: true) }
  let(:strlen) { "Meal Reminder: Meal X".size }
  let(:dbl) { double(deliver_now: nil) }
  subject { mails_sent }

  around do |example|
    Timecop.freeze(Time.zone.parse("2017-01-01 00:00") + Settings.reminders.time_of_day.hours) do
      example.run
    end
  end

  it "sends the right number of emails" do
    expect(NotificationMailer).to receive(:meal_reminder).exactly(4).times.and_return(dbl)
    described_class.new.perform
  end

  it "sends correct emails" do
    expect(NotificationMailer).to receive(:meal_reminder).with(user1, signup1).and_return(dbl)
    expect(NotificationMailer).to receive(:meal_reminder).with(user1, signup2).and_return(dbl)
    expect(NotificationMailer).to receive(:meal_reminder).with(user2, signup3).and_return(dbl)
    expect(NotificationMailer).to receive(:meal_reminder).with(user3, signup3).and_return(dbl)
    described_class.new.perform
  end

  it "sets notified flag" do
    described_class.new.perform
    expect([signup1, signup2, signup3].map(&:reload).map(&:notified?)).to eq [true, true, true]
    expect(signup4.reload.notified?).to be false
  end
end
