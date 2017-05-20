require 'rails_helper'

describe Meals::ShiftReminderJob do
  # Two meals in the window, one outside the window, one already notified.
  let!(:meal1) { create(:meal, :with_menu, :with_asst, title: "Meal 1", served_at: "2017-01-02 18:15") }
  let!(:meal2) { create(:meal, :with_menu, :with_asst, title: "Meal 2", served_at: "2017-01-02 18:15") }
  let!(:meal3) { create(:meal, :with_menu, :with_asst, title: "Meal 3", served_at: "2017-01-04 18:15") }
  let!(:meal4) { create(:meal, :with_menu, :with_asst, title: "Meal 4", served_at: "2017-01-20 18:15") }
  let(:dbl) { double(deliver_now: nil) }

  around do |example|
    Timecop.freeze(Time.zone.parse("2017-01-01 00:00") + Settings.reminders.time_of_day.hours) do
      example.run
    end
  end

  before do
    # Make meal2 already notified.
    meal2.asst_cook_assigns[0].update_attribute(:reminder_count, 1)
  end

  it "sends the right number of emails" do
    expect(NotificationMailer).to receive(:shift_reminder).exactly(4).times.and_return(dbl)
    described_class.new.perform
  end

  it "sends correct emails" do
    # Both should go for meal1.
    expect(NotificationMailer).to receive(:shift_reminder).with(meal1.head_cook_assign).and_return(dbl)
    expect(NotificationMailer).to receive(:shift_reminder).with(meal1.asst_cook_assigns[0]).and_return(dbl)

    # Meal 2 asst_cook already sent.
    expect(NotificationMailer).to receive(:shift_reminder).with(meal2.head_cook_assign).and_return(dbl)

    # Meal 3 too early for asst_cook, but not head cook.
    expect(NotificationMailer).to receive(:shift_reminder).with(meal3.head_cook_assign).and_return(dbl)

    # Meal 4 outside window.
    described_class.new.perform
  end

  it "updates notification count" do
    described_class.new.perform
    meals = [meal1, meal2, meal3, meal4].map(&:reload)
    assigns = meals.map { |m| [m.head_cook_assign, m.asst_cook_assigns[0]] }.flatten
    expect(assigns.map(&:reminder_count)).to eq [1, 1, 1, 1, 1, 0, 0, 0]
  end
end
