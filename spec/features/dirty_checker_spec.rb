require "rails_helper"

feature "dirty checker" do
  let(:admin) { create(:admin) }
  let!(:meal_location) { create(:resource, name: "Dining Room", meal_hostable: true) }

  around { |ex| with_user_home_subdomain(admin) { ex.run } }

  before do
    login_as(admin, scope: :user)
  end

  scenario "meals form", js: true do
    visit(new_meal_path)
    expect_no_confirm_on_reload
    enter_datetime(I18n.l(Time.now, format: :full_datetime), into: "meal_served_at")
    expect_confirm_on_reload
    # Tried to test more field types but it was taking forever.
  end

  scenario "user form", js: true do
    visit(new_user_path)
    expect_no_confirm_on_reload
  end
end
