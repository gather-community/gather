# frozen_string_literal: true

require "rails_helper"

describe "meal import", :js, :perform_jobs do
  let(:actor) { create(:admin) }
  let!(:resource) { create(:resource, name: "Dining Room") }
  let!(:formula) { create(:meal_formula, is_default: true) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit(meals_path)
    expect(page).to have_title("Meals")

    find("button.dropdown-toggle").click
    click_link("Import Meals")
    click_button("Import")

    expect(page).to have_content("can't be blank")
    expect(page).not_to have_content("Data Format")

    drop_in_dropzone(fixture_file_path("meals/import/simple_data.csv"))
    click_button("Import")

    expect(page).to have_content("Your import succeeded")
    expect(page).not_to have_content("Data Format")
  end

  scenario "bad data" do
    visit(new_meals_import_path)
    drop_in_dropzone(fixture_file_path("meals/import/bad_data.csv"))
    click_button("Import")

    expect(page).to have_content("There were one or more issues with your meal data")
    expect(page).to have_content("Data Format")
  end

  scenario "crash" do
    with_env("STUB_IMPORT_ERROR" => "Unexpected error") do
      visit(new_meals_import_path)
      drop_in_dropzone(fixture_file_path("meals/import/simple_data.csv"))
      click_button("Import")

      expect(page).to have_content("We encountered an unexpected error during import.")
      expect(page).to have_content("Data Format")
    end
  end
end
