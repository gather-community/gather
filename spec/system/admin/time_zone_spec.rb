# frozen_string_literal: true

require "rails_helper"

describe "time zones" do
  let!(:meal) { create(:meal, served_at: "2017-01-01 18:00 UTC") }
  let(:actor) { create(:admin) }

  around do |example|
    # Freeze to a time on the morning of the meal.
    Timecop.freeze(Time.zone.parse("2017-01-01 9:00 UTC")) do
      example.run
    end
  end

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "meal time" do
    visit "/meals"
    expect(page).to have_content("Sun Jan 01 6:00pm")
    visit "/admin/settings/community"
    select("(GMT-03:30) Newfoundland", from: "Time Zone")
    click_button("Save")
    expect(page).to have_content("Settings updated successfully.")
    visit "/meals"
    expect(page).to have_content("Sun Jan 01 2:30pm")
  end
end
