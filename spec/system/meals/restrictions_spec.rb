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

    click_button("Save")

    expect(page).to have_content("Please review the problems below:")

    within(all("#nested-field-table-rows tr")[0]) do
      find("input[aria-label=Restriction]").set("gluten")
      find("input[aria-label=Opposite]").set("no gluten")
    end

    click_button("Save")

    expect(page).to have_success_alert("Updated successfully")

    within(all("#nested-field-table-rows tr")[0]) do
      expect(page).to have_field("community_restrictions_attributes_0_contains", with: "gluten")
      expect(page).to have_field("community_restrictions_attributes_0_absence", with: "no gluten")
    end

    click_on("Add Restriction")

    within(all("#nested-field-table-rows tr")[1]) do
      find("input[aria-label=Restriction]").set("spicy")
      find("input[aria-label=Opposite]").set("not spicy")
    end

    click_button("Save")

    within(all("#nested-field-table-rows tr")[1]) do
      expect(page).to have_field("community_restrictions_attributes_1_contains", with: "spicy")
      expect(page).to have_field("community_restrictions_attributes_1_absence", with: "not spicy")
    end
  end
end
