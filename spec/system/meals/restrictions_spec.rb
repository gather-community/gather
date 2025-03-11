# frozen_string_literal: true

require "rails_helper"

describe "restrictions settings", js: true do
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit(edit_meals_restrictions_path)

    click_link("Add restriction")
    fill_in("Contains", with: "gluten")
    fill_in("Absence", with: "no gluten")
    click_button("Save")

    expect(page).to have_success_alert("Updated successfully")
    expect(page).to have_field("Contains", with: "gluten")
  end
end
