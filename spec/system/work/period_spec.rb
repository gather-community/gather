# frozen_string_literal: true

require "rails_helper"

describe "periods", js: true do
  let(:actor) { create(:work_coordinator) }
  let!(:period1) do
    create(:work_period,
           name: "Foo",
           starts_on: "2017-01-01",
           ends_on: "2017-04-30",
           phase: "archived")
  end
  let!(:period2) do
    create(:work_period,
           name: "Bar",
           starts_on: "2017-05-01",
           ends_on: "2017-08-31",
           phase: "active")
  end
  let!(:period3) do
    create(:work_period,
           name: "Baz",
           starts_on: "2017-09-01",
           ends_on: "2017-12-31",
           phase: "draft")
  end
  let!(:user1) { create(:user, first_name: "Jane", last_name: "Picard") }
  let!(:user2) { create(:user, first_name: "Churl", last_name: "Rox") }
  let!(:user3) { create(:user, :child, first_name: "Kid", last_name: "Knelt") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "index" do
    visit(work_periods_path)
    expect(page).to have_title("Work Periods")
    expect(page).to have_css("table.index tr", count: 4) # Header plus two rows
    expect(page).to have_css("table.index tr td.name", text: "Foo")
  end

  scenario "create, show, update" do
    visit(work_periods_path)
    click_on("Create Period")
    fill_basic_fields

    # There are no formulas/roles so this shouldn't be there.
    expect(page).not_to have_content("Meal Job Sync")

    # Set quota attrib and choose share values
    expect(page).not_to have_content("Pick Type")
    expect(page).not_to have_select("Jane Picard")
    select("By Household", from: "Quota")
    expect(page).to have_select("Jane Picard", selected: "Full Share")
    expect(page).to have_select("Churl Rox", selected: "Full Share")
    expect(page).to have_select("Kid Knelt", selected: "No Share")
    select("Full Share", from: "Jane Picard")
    select("½ Share", from: "Churl Rox")

    # Set auto open time, pick type, and staggering options
    expect(page).not_to have_content("Round Duration")
    pick_datetime(".work_period_auto_open_time", day: 1, hour: 12)
    select("Groups of workers take turns choosing", from: "Pick Type")
    fill_in("Max. Rounds per Worker", with: 2)
    fill_in("Workers per Group", with: 5)
    select("3 minutes", from: "Round Duration")

    click_button("Save")

    # Simulate user creation after period is created.
    create(:user, first_name: "Blep", last_name: "Cruller")

    click_on("Qux")
    expect(page).to have_content("By Household")
    expect(page).to have_content("Churl Rox")
    expect(page).to have_content("½ Share")

    click_on("Edit")
    expect(page).to have_select("Churl Rox", selected: "½ Share")
    expect(page).to have_select("Blep Cruller", selected: "")
    expect(page).to have_select("Pick Type", selected: "Groups of workers take turns choosing")
    expect(page).to have_select("Round Duration", selected: "3 minutes")
    select("½ Share", from: "Blep Cruller")
    click_button("Save")

    click_on("Qux")
    click_on("Edit")
    expect(page).to have_select("Blep Cruller", selected: "½ Share")
  end

  scenario "priority star works and persisted after save" do
    visit(work_periods_path)
    click_on("Create Period")
    fill_basic_fields
    select("By Household", from: "Quota")
    expect(page).not_to have_css(".priority-icon")
    pick_datetime(".work_period_auto_open_time", day: 1, hour: 12)
    select("Groups of workers take turns choosing", from: "Pick Type")
    expect(page).to have_css(".priority-icon")
    all(".priority-icon")[0].click
    click_button("Save")
    click_on("Qux")
    click_on("Edit")
    expect(all(".priority-icon")[0]).to have_content("★")
    expect(all(".priority-icon")[1]).to have_content("☆")

    # Test dirty check - Testing dirty check is not working currently.
    # The confirmation dialog does not seem to show.
    # page.go_back
    # click_on("Edit")
    # all(".priority-icon")[0].click
    # dismiss_confirm { page.go_back }
    # all(".priority-icon")[0].click
    # page.go_back
  end

  scenario "destroy" do
    visit(work_periods_path)
    click_on("Baz")
    click_on("Edit")
    accept_confirm { click_on("Delete") }
    expect(page).to have_content("deleted successfully")
  end

  context "with period with shares and jobs" do
    let!(:users) { create_list(:user, 5) }
    let!(:period4) do
      create(:work_period, :with_shares, name: "Charlie", quota_type: "by_person", pick_type: "staggered",
                                         starts_on: "2020-02-01", ends_on: "2020-04-30",
                                         round_duration: 5, auto_open_time: "2020-01-15 12:00",
                                         max_rounds_per_worker: 3, workers_per_round: 10)
    end
    let!(:job) do
      create(:work_job, period: period4, title: "Frungler", time_type: "date_only", hours: 2,
                        shift_starts: ["2020-02-03"], shift_ends: ["2020-02-03"])
    end

    scenario "clone" do
      visit(work_periods_path)
      click_on("Charlie")
      click_on("Clone")
      expect(page).to have_info_alert("data have been copied")
      expect(page).to have_field("Workers per Group", with: "10")
      expect(page).to have_select(users[0].name)
      fill_in("Name", with: "Delta")
      pick_datetime(".work_period_auto_open_time", day: 1, hour: 12)
      click_on("Save")
      expect(page).to have_success_alert

      click_on("Jobs")
      select_lens(:period, "Delta")
      expect(page).to have_content("Frungler")
    end

    scenario "clone with no job copy" do
      visit(work_periods_path)
      click_on("Charlie")
      click_on("Clone")
      expect(page).to have_info_alert("data have been copied")
      expect(page).to have_field("Workers per Group", with: "10")
      expect(page).to have_select(users[0].name)
      fill_in("Name", with: "Delta")
      pick_datetime(".work_period_auto_open_time", day: 1, hour: 12)
      expect(page).to have_content("Copy pre-assignments?")
      select("Do not copy jobs", from: "Job Copy")
      expect(page).not_to have_content("Copy pre-assignments?")
      click_on("Save")
      expect(page).to have_success_alert

      click_on("Jobs")
      select_lens(:period, "Delta")
      expect(page).not_to have_content("Frungler")
    end
  end

  context "with meal formulas/roles" do
    let!(:role1) { create(:meal_role, :head_cook, title: "Honcho") }
    let!(:role2) { create(:meal_role, title: "Flunkie") }
    let!(:formula1) { create(:meal_formula, roles: [role1, role2]) }

    scenario "meal job sync settings are saved properly" do
      visit(work_periods_path)
      click_on("Create Period")
      find("#work_period_meal_job_sync").select("Sync meal jobs for selected formulas and roles")
      check("Honcho")
      click_on("Save")

      expect(page).to have_alert("Please review the problems below")
      expect(page).to have_checked_field("Honcho")
      expect(page).to have_unchecked_field("Flunkie")

      fill_basic_fields
      click_on("Save")

      expect(page).to have_alert("created successfully")
      click_on("Qux")
      click_on("Edit")
      expect(page).to have_checked_field("Honcho")
      expect(page).to have_unchecked_field("Flunkie")
    end
  end

  def fill_basic_fields
    select("Open", from: "Phase")
    pick_date(".work_period_starts_on", day: 15)
    pick_date(".work_period_ends_on", day: 20)
    fill_in("Name", with: "Qux")
  end
end
