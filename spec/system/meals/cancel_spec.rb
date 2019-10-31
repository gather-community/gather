# frozen_string_literal: true

require "rails_helper"

feature "meal messages" do
  let(:formula) { create(:meal_formula, :with_two_roles) }
  let!(:meal) { create(:meal, formula: formula, asst_cooks: [create(:user)]) }
  let!(:user) { meal.head_cook }
  let!(:signup) { create_list(:meal_signup, 2, meal: meal, diner_counts: [2, 1]) }
  let(:email_sent) { email_sent_by { process_queued_job } }

  before do
    use_user_subdomain(user)
    login_as(meal.head_cook, scope: :user)
  end

  scenario "cancel meal" do
    visit meal_path(meal)
    click_link "Cancel"
    fill_in "Message", with: "Foo bar"
    click_button "Send Message"
    expect(page).to have_content("Message sent successfully")
    expect(page).to have_content("This meal has been cancelled")
    expect(email_sent.size).to eq(4) # Signed up households + team
  end
end
