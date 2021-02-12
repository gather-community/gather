# frozen_string_literal: true

require "rails_helper"

describe "work settings", js: true do
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit(edit_work_settings_path)
    expect(page).to have_select("Default Signup Date Filter", selected: "Past & Future")

    select("Current & Future", from: "Default Signup Date Filter")
    click_button("Save")

    expect(page).to have_success("Settings updated successfully.")
    expect(page).to have_select("Default Signup Date Filter", selected: "Current & Future")
  end
end
