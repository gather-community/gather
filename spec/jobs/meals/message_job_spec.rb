# frozen_string_literal: true

require "rails_helper"

describe Meals::MessageJob do
  include_context "jobs"

  let(:formula) { create(:meal_formula, :with_three_roles) }
  let!(:meal) { create(:meal, formula: formula, asst_cooks: [create(:user)], cleaners: [create(:user)]) }
  let!(:signups) { create_list(:meal_signup, 2, meal: meal, diner_counts: [2, 1]) }
  let!(:hholds) { signups.map(&:household) }
  subject(:job) { described_class.new(message.id) }

  describe "normal messages" do
    describe "message to diners" do
      let!(:message) { create(:meal_message, meal: meal, recipient_type: "diners") }

      it "should send correct number of emails" do
        expect(MealMailer).to receive(:normal_message).exactly(2).times.and_return(mlrdbl)
        perform_job
      end

      it "should send message to correct households" do
        expect_households
        perform_job
      end
    end

    describe "message to team" do
      let!(:message) { create(:meal_message, meal: meal, recipient_type: "team", sender: meal.head_cook) }

      it "should send correct number of emails" do
        expect(MealMailer).to receive(:normal_message).exactly(3).times.and_return(mlrdbl)
        perform_job
      end

      it "should send message to correct workers" do
        expect_workers
        perform_job
      end
    end

    describe "message to all" do
      let!(:message) { create(:meal_message, meal: meal, recipient_type: "all", sender: meal.head_cook) }

      it "should send correct number of emails" do
        expect(MealMailer).to receive(:normal_message).exactly(5).times.and_return(mlrdbl)
        perform_job
      end

      it "should send message to correct households and users" do
        expect_workers
        expect_households
        perform_job
      end
    end
  end

  def expect_workers
    meal.workers.each do |user|
      expect(MealMailer).to receive(:normal_message).with(message, user).and_return(mlrdbl)
    end
  end

  def expect_households
    hholds.each do |hhold|
      expect(MealMailer).to receive(:normal_message).with(message, hhold).and_return(mlrdbl)
    end
  end
end
