require 'rails_helper'

describe Meals::MessageJob do
  include_context "jobs"

  describe "diner message" do
    let!(:meal) { create(:meal) }
    let!(:signups) { create_list(:signup, 2, :with_nums, meal: meal) }
    let!(:hholds) { signups.map(&:household) }
    let!(:message) { create(:meal_message, meal: meal, recipient_type: "diners") }

    it "should send correct number of emails" do
      expect(MealMailer).to receive(:meal_message).exactly(2).times.and_return(mlrdbl)
      perform_job(message.id)
    end

    it "should send message to correct households" do
      hholds.each do |hhold|
        expect(MealMailer).to receive(:meal_message).with(message, hhold).and_return(mlrdbl)
      end
      perform_job(message.id)
    end
  end

  describe "team message" do
    let!(:meal) { create(:meal, asst_cooks: [create(:user)], cleaners: [create(:user)]) }
    let!(:message) { create(:meal_message, meal: meal, recipient_type: "team", sender: meal.head_cook) }

    it "should send correct number of emails" do
      expect(MealMailer).to receive(:meal_message).exactly(2).times.and_return(mlrdbl)
      perform_job(message.id)
    end

    it "should send message to correct households" do
      (meal.workers - [meal.head_cook]).each do |user|
        expect(MealMailer).to receive(:meal_message).with(message, user).and_return(mlrdbl)
      end
      perform_job(message.id)
    end
  end
end
