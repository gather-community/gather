# frozen_string_literal: true

require "rails_helper"

describe "meal messages", :perform_jobs do
  let(:formula) { create(:meal_formula, :with_two_roles) }
  let!(:meal) { create(:meal, formula: formula, asst_cooks: [create(:user)]) }
  let!(:user) { meal.head_cook }
  let!(:signup) { create(:meal_signup, meal: meal, diner_counts: [2, 1]) }

  before do
    use_user_subdomain(user)
    login_as(meal.head_cook, scope: :user)
  end

  shared_examples_for "sends message" do |recipient_type, email_count|
    scenario do
      email_sent = email_sent_by do
        visit(meal_path(meal))
        click_link("Message")
        select(recipient_type, from: "Recipients")
        fill_in("Message", with: "Foo bar")
        click_button("Send Message")
        expect(page).to have_content("Message sent successfully")
      end
      expect(email_sent.size).to eq(email_count)
    end
  end

  it_behaves_like "sends message", "Diners", 1
  it_behaves_like "sends message", "Team", 2
  it_behaves_like "sends message", "Diners + Team", 3
end
