# frozen_string_literal: true

require "rails_helper"

describe Meals::MealReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  let(:c2) { create(:community) }
  let!(:meal1) { create(:meal, :with_menu, title: "Meal 1", served_at: "2017-01-01 18:15") }
  let!(:meal2) { create(:meal, :with_menu, title: "Meal 2", served_at: "2017-01-01 18:15", community: c2) }
  let!(:meal3) { create(:meal, :with_menu, title: "Meal 3", served_at: "2017-01-02 18:15") }
  let!(:meal4) { create(:meal, :with_menu, :cancelled, title: "Meal 4", served_at: "2017-01-01 18:15") }
  let!(:signup1) { create(:meal_signup,meal: meal1, diner_counts: [2, 1]) }
  let!(:signup2) { create(:meal_signup,meal: meal2, diner_counts: [2, 1]) }
  let!(:signup3) { create(:meal_signup,meal: meal2, diner_counts: [2, 1]) }
  let!(:signup4) { create(:meal_signup,meal: meal3, diner_counts: [2, 1]) }
  let!(:signup5) { create(:meal_signup,meal: meal1, diner_counts: [2, 1], notified: true) }
  let(:strlen) { "Meal Reminder: Meal X".size }

  it "sends the right number of emails" do
    expect(MealMailer).to receive(:meal_reminder).exactly(3).times.and_return(mlrdbl)
    perform_job
  end

  it "sends correct emails" do
    expect(MealMailer).to receive(:meal_reminder).with(signup1).and_return(mlrdbl)
    expect(MealMailer).to receive(:meal_reminder).with(signup2).and_return(mlrdbl)
    expect(MealMailer).to receive(:meal_reminder).with(signup3).and_return(mlrdbl)
    perform_job
  end

  it "sets notified flag" do
    perform_job
    expect([signup1, signup2, signup3].map(&:reload).map(&:notified?)).to eq [true, true, true]
    expect(signup4.reload.notified?).to be false
  end
end
