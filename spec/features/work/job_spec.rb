# frozen_string_literal: true

require "rails_helper"

feature "jobs", js: true do
  include_context "work"

  let(:actor) { create(:work_coordinator) }
  let(:index_path) { work_jobs_path }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  it_behaves_like "handles no periods"

  context "with period but no jobs" do
    let!(:period) { create(:work_period) }

    scenario "index" do
      visit(index_path)
      expect(page).to have_content("No jobs found")
    end
  end

  context "with period and jobs" do
    let(:period) { create(:work_period) }
    let!(:groups) { create_list(:people_group, 2) }
    let!(:users) { create_list(:user, 3) }
    let!(:jobs) do
      [create(:work_job, period: period), create(:work_job, period: period, slot_type: "full_single")]
    end

    scenario "index" do
      visit(work_jobs_path)
      expect(page).to have_title("Jobs")
      expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
    end

    # NOTE: THIS SPEC IS NOT WORKING ON TRAVIS DUE TO PICK_DATETIME METHOD.
    # SWITCHING TO CHROME HEADLESS MAY FIX IT, AND WE NEED TO DO THAT ANYWAY.
    # FOR NOW, SKIPPING IT. BUT THIS SHOULD GET FIXED.
    scenario "create, show, and update", :notravis do
      visit(work_jobs_path)
      click_link("Create")
      fill_in("Title", with: "AAA Painter")
      fill_in("Hours", with: "2")
      select(groups.first.name, from: "Requester")
      fill_in("Description", with: "Paints things nicely")

      # Add first shift
      within(all("#shift-rows tr")[0]) do
        pick_datetime(".starts-at", day: 15, hour: 4, next_click: ".shift-slots input")
        pick_datetime(".ends-at", day: 15, hour: 6, next_click: ".shift-slots input")
        find(".shift-slots input").set(2)
      end

      # Add a second shift
      click_on("Add Shift")
      within(all("#shift-rows tr")[1]) do
        pick_datetime(".starts-at", day: 15, hour: 5, next_click: ".shift-slots input")
        pick_datetime(".ends-at", day: 15, hour: 7, next_click: ".shift-slots input")
        find(".shift-slots input").set(4)

        # Add three workers but delete one.
        click_on("Add Worker")
        select2(users[0].name, from: all("select.assoc_select2")[0])
        click_on("Add Worker")
        select2(users[1].name, from: all("select.assoc_select2")[1])
        select2(:clear, from: all("select.assoc_select2")[1])
        select2(users[2].name, from: all("select.assoc_select2")[1])
      end
      click_on("Create Job")

      expect_success
      within(all("table.index tr")[1]) do
        expect(page).to have_css("td.title", text: "AAA Painter")
        expect(page).to have_css("td.slots", text: 6)
      end
      click_link("AAA Painter")

      # Check for workers added earlier
      within(all("#shift-rows tr")[1]) do
        expect(page).to have_content(users[0].name)
        expect(page).not_to have_content(users[1].name)
        expect(page).to have_content(users[2].name)
      end

      # Remove previous shift and add a new one.
      all("#shift-rows tr")[1].find("a.remove_fields").click
      click_on("Add Shift")
      within(all("#shift-rows tr")[1]) do
        pick_datetime(".starts-at", day: 15, hour: 9, next_click: ".shift-slots input")
        pick_datetime(".ends-at", day: 15, hour: 11, next_click: ".shift-slots input")
        find(".shift-slots input").set(6)
      end
      click_on("Update Job")

      expect_success
      within(all("table.index tr")[1]) do
        expect(page).to have_css("td.slots", text: 8)
      end
    end

    scenario "delete" do
      visit(edit_work_job_path(jobs.first))
      accept_confirm { click_on("Delete") }
      expect_success
      expect(page).not_to have_content(jobs.first.title)
    end
  end
end
