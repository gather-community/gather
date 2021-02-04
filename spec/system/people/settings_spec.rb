# frozen_string_literal: true

require "rails_helper"

describe "people settings", js: true do
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit(edit_people_settings_path)
    expect(page).to have_select("Default Directory Sort", selected: "By Name")

    select("By Unit", from: "Default Directory Sort")
    click_button("Save")

    expect(page).to have_success("Settings updated successfully.")
    expect(page).to have_select("Default Directory Sort", selected: "By Unit")
  end
end
