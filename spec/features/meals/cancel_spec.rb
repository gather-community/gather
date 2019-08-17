# frozen_string_literal: true

require "rails_helper"

feature "meal messages" do
  let!(:meal) { create(:meal, asst_cooks: [create(:user)]) }
  let!(:user) { meal.head_cook }
  let!(:signup) { create_list(:meal_signup, 2, meal: meal, diner_counts: [2, 1]) }
  let(:email_sent) { email_sent_by { process_queued_job } }

  around do |example|
    with_user_home_subdomain(user) { example.run }
  end

  before do
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
