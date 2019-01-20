# frozen_string_literal: true

require "rails_helper"

describe Meals::ShiftReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  # Two meals in the window, one outside the window, one already notified, one cancelled.
  let!(:meal1) { create(:meal, :with_menu, :with_asst, title: "Meal 1", served_at: "2017-01-02 18:15") }
  let!(:meal2) { create(:meal, :with_menu, :with_asst, title: "Meal 2", served_at: "2017-01-02 18:15") }
  let!(:meal3) { create(:meal, :with_menu, :with_asst, title: "Meal 3", served_at: "2017-01-04 18:15") }
  let!(:meal4) { create(:meal, :with_menu, :with_asst, title: "Meal 4", served_at: "2017-01-20 18:15") }
  let!(:meal5) do
    create(:meal, :with_menu, :cancelled, :with_asst, title: "Meal 5", served_at: "2017-01-02 18:15")
  end

  before do
    # Make meal2 already notified.
    meal2.assignments[1].update!(reminder_count: 1)
  end

  it "sends the right number of emails" do
    expect(MealMailer).to receive(:shift_reminder).exactly(4).times.and_return(mlrdbl)
    perform_job
  end

  it "sends correct emails" do
    # Both should go for meal1.
    expect(MealMailer).to receive(:shift_reminder).with(meal1.assignments[0]).and_return(mlrdbl)
    expect(MealMailer).to receive(:shift_reminder).with(meal1.assignments[1]).and_return(mlrdbl)

    # Meal 2 asst_cook already sent.
    expect(MealMailer).to receive(:shift_reminder).with(meal2.assignments[0]).and_return(mlrdbl)

    # Meal 3 too early for asst_cook, but not head cook.
    expect(MealMailer).to receive(:shift_reminder).with(meal3.assignments[0]).and_return(mlrdbl)

    # Meal 4 outside window.
    perform_job
  end

  it "updates notification count" do
    perform_job
    meals = [meal1, meal2, meal3, meal4].map(&:reload)
    assigns = meals.map { |m| [m.assignments[0], m.assignments[1]] }.flatten
    expect(assigns.map(&:reminder_count)).to eq([1, 1, 1, 1, 1, 0, 0, 0])
  end
end
