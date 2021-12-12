# frozen_string_literal: true

require "rails_helper"

describe "meals settings", js: true do
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit(edit_meals_settings_path)

    fill_in("Default Capacity", with: 51)
    click_button("Save")

    expect(page).to have_success("Settings updated successfully.")
    expect(page).to have_field("Default Capacity", with: "51")
  end
end
