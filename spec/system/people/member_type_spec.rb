# frozen_string_literal: true

require "rails_helper"

describe "member types", js: true do
  let(:page_path) { people_member_types_path }
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "index, create, update, destroy" do
    visit(page_path)
    expect(page).to have_content("No member types found")
    click_link("Create Member Type")

    fill_in("Name", with: "Squengler")
    click_on("Save")

    expect_success
    click_on("Squengler")

    fill_in("Name", with: "Pongler")
    click_on("Save")

    expect_success
    click_on("Pongler")

    accept_confirm { click_link("Delete") }

    expect_success
    expect(page).to have_content("No member types found")
  end
end
