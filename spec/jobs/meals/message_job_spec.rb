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
    let!(:calls) { record_notifications(MealMailer, :normal_message) }

    describe "message to diners" do
      let!(:message) { create(:meal_message, meal: meal, recipient_type: "diners") }

      it "sends each household one message" do
        perform_job
        expect(calls.map { |_group, _message, greeted| greeted }).to match_array(hholds)
        calls.each { |group, _message, greeted| expect(group).to match_array(greeted.users) }
      end
    end

    describe "message to team" do
      let!(:message) { create(:meal_message, meal: meal, recipient_type: "team", sender: meal.head_cook) }

      it "sends each worker their own message" do
        perform_job
        expect(calls.map { |_group, _message, greeted| greeted }).to match_array(meal.workers)
        calls.each { |group, _message, greeted| expect(group).to eq([greeted]) }
      end
    end

    describe "message to all" do
      let!(:message) { create(:meal_message, meal: meal, recipient_type: "all", sender: meal.head_cook) }

      it "sends the workers and the households their own messages" do
        perform_job
        expect(calls.map { |_group, _message, greeted| greeted }).to match_array(meal.workers + hholds)
      end
    end
  end

  describe "a household whose members read email in different languages" do
    let(:household) { hholds.first }
    let!(:message) { create(:meal_message, meal: meal, recipient_type: "diners") }

    before do
      create(:feature_flag, name: "i18n", status: true)
      household.users.first.update!(locale: "de")
      create(:user, household: household, locale: "fr")
    end

    it "gets one message per language, each in that language" do
      emails = email_sent_by { perform_job }.select { |email| (email.to & household.users.map(&:email)).any? }
      expect(emails.size).to eq(2)
      by_address = emails.to_h { |email| [email.to, email.subject] }
      german, french = household.users.partition { |user| user.locale == "de" }
      expect(by_address[german.map(&:email)]).to start_with("Nachricht zur Mahlzeit")
      expect(by_address[french.map(&:email)]).to start_with("Message au sujet du repas")
    end
  end
end
