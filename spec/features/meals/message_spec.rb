require "rails_helper"

feature "meal messages" do
  let!(:meal) { create(:meal, asst_cooks: [create(:user)]) }
  let!(:user) { meal.head_cook }
  let!(:signup) { create(:signup, :with_nums, meal: meal) }

  around do |example|
    with_user_home_subdomain(user) { example.run }
  end

  before do
    login_as(meal.head_cook, scope: :user)
  end

  shared_examples_for "sends message" do |link|
    scenario do
      expect do
        visit meal_path(meal)
        click_link "Contact Team"
        fill_in "Message", with: "Foo bar"
        click_button "Send Message"
        expect(page).to have_content("Message sent successfully")
        Delayed::Worker.new.work_off
      end.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  it_behaves_like "sends message", "Contact Diners"
  it_behaves_like "sends message", "Contact Team"
end
