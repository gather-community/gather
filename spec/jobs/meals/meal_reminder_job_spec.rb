require 'rails_helper'

describe Meals::MealReminderJob do
  include_context "jobs"
  include_context "reminder jobs"

  let(:c2) { create(:community) }
  let!(:meal1) { create(:meal, :with_menu, title: "Meal 1", served_at: "2017-01-01 18:15") }
  let!(:meal2) { create(:meal, :with_menu, title: "Meal 2", served_at: "2017-01-01 18:15", community: c2) }
  let!(:meal3) { create(:meal, :with_menu, title: "Meal 3", served_at: "2017-01-02 18:15") }
  let!(:signup1) { create(:signup, :with_nums, meal: meal1) }
  let!(:signup2) { create(:signup, :with_nums, meal: meal2) }
  let!(:signup3) { create(:signup, :with_nums, meal: meal2) }
  let!(:signup4) { create(:signup, :with_nums, meal: meal3) }
  let!(:signup5) { create(:signup, :with_nums, meal: meal1, notified: true) }
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
