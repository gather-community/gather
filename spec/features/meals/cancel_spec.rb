require "rails_helper"

feature "meal messages" do
  let!(:meal) { create(:meal, asst_cooks: [create(:user)]) }
  let!(:user) { meal.head_cook }
  let!(:signup) { create_list(:signup, 2, :with_nums, meal: meal) }

  around do |example|
    with_user_home_subdomain(user) { example.run }
  end

  before do
    login_as(meal.head_cook, scope: :user)
  end

  scenario "cancel meal" do
    expect do
      visit meal_path(meal)
      click_link "Cancel"
      fill_in "Message", with: "Foo bar"
      click_button "Send Message"
      expect(page).to have_content("Message sent successfully")
      expect(page).to have_content("This meal has been cancelled")
      Delayed::Worker.new.work_off
    end.to change { ActionMailer::Base.deliveries.size }.by(4) # Signed up households + team
  end
end
