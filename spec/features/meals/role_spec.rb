# frozen_string_literal: true

require "rails_helper"

feature "roles", js: true do
  let(:actor) { create(:meals_coordinator) }
  let!(:roles) { create_list(:meal_role, 2) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "index" do
    visit(meals_roles_path)
    expect(page).to have_title("Meal Roles")
    expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
  end

  scenario "create and update" do
    visit(meals_roles_path)
    click_link("Create Role")
    fill_in("Title", with: "Assistant Cook")
    fill_in("People per Meal", with: 2)
    select("date and time", from: "Times")
    fill_in("Start Time", with: -180)
    fill_in("End Time", with: -200)
    fill_in("Job Description", with: "Cook the food!")
    check("The same person can sign up more than once")

    # Add reminders
    within(all(".meals_role_reminders .nested-fields")[0]) do
      find(".meals_role_reminders_rel_magnitude input").set("2.3")
      find(".meals_role_reminders_rel_unit_sign select").select("Days After")
      fill_in("Note", with: "Salt the fish")
    end
    click_on("Add Reminder")
    within(all(".meals_role_reminders .nested-fields")[1]) do
      find(".meals_role_reminders_rel_magnitude input").set("2")
      find(".meals_role_reminders_rel_unit_sign select").select("Days Before")
    end
    click_button("Save")

    expect_validation_error("Must be after")
    fill_in("End Time", with: -30)
    click_button("Save")

    expect_success
    expect(page).to have_content("Assistant Cook 2")
    click_link("Assistant Cook")
    fill_in("People per Meal", with: "3")
    click_button("Save")

    expect_success
    expect(page).to have_content("Assistant Cook 3")
  end

  scenario "deactivate/activate/delete" do
    visit(edit_meals_role_path(roles.first))
    accept_confirm { click_on("Deactivate") }

    expect_success
    click_link("#{roles.first.title} (Inactive)")
    click_link("reactivate it")

    expect_success
    expect(page).not_to have_content("#{roles.first.title} (Inactive)")
    click_link(roles.first.title)

    accept_confirm { click_on("Delete") }

    expect_success
    expect(page).not_to have_content(roles.first.title)
  end
end
