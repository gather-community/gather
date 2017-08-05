require "rails_helper"

feature "meal signups" do
  let(:user) { create(:user) }
  let!(:formula) { create(:meal_formula) }
  let!(:meal) { create(:meal, served_at: Time.now + 7.days) }

  around do |example|
    with_user_home_subdomain(user) { example.run }
  end

  before do
    login_as(user, scope: :user)
  end

  scenario "signup for meal, fix validation error, submit again" do
    visit meal_path(meal)
    click_button("Save")
    expect(page).to have_content("You must sign up at least one person")
    select "2", from: "signup_adult_meat"
    click_button("Save")
    expect(page).to have_title("Meals")
  end
end
