# frozen_string_literal: true

require "rails_helper"

describe "jobs", js: true do
  include_context "work"

  let(:actor) { create(:work_coordinator) }
  let(:page_path) { work_jobs_path }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  it_behaves_like "handles no periods"

  context "with period but no jobs" do
    let!(:period) { create(:work_period) }

    scenario "index" do
      visit(page_path)
      expect(page).to have_content("No jobs found")
    end
  end

  context "with period and jobs" do
    include_context "with jobs"
    include_context "with assignments"

    scenario "index" do
      visit(work_jobs_path)
      expect(page).to have_title("Jobs")
      expect_jobs(*jobs[0..3])
      expect(page).to have_content("Cook")
      expect(page).to have_css("i.fa-cutlery")

      select_lens(:requester, group.name)
      expect_jobs(jobs[1], jobs[3])

      clear_lenses
      select_lens(:pre, "Preassigned")
      expect_jobs(jobs[0])

      select_lens(:pre, "Not Preassigned")
      expect_jobs(*jobs[1..3])

      clear_lenses
      select_lens(:period, periods[1].name)
      expect_jobs(jobs[4])
    end

    # TODO: THIS SPEC IS NOT WORKING ON TRAVIS DUE TO PICK_DATETIME METHOD.
    # SWITCHING TO CHROME HEADLESS MAY FIX IT, AND WE NEED TO DO THAT ANYWAY.
    # FOR NOW, SKIPPING IT. BUT THIS SHOULD GET FIXED.
    scenario "create, show, and update", :notravis do
      visit(work_jobs_path)
      click_link("Create")
      fill_in("Title", with: "AAA Painter")
      fill_in("Hours", with: "2")
      select(group.name, from: "Requester")
      fill_in("Description", with: "Paints things nicely")

      # Add reminders
      within(all(".work_job_reminders .nested-fields")[0]) do
        find(".work_job_reminders_rel_magnitude input").set("2.3")
        find(".work_job_reminders_rel_unit_sign select").select("Days Before")
        fill_in("Note", with: "Clean the lint trap")
      end
      click_on("Add Reminder")
      within(all(".work_job_reminders .nested-fields")[1]) do
        find(".work_job_reminders_abs_rel select").select("Exact Time")
        pick_datetime(".work_job_reminders_abs_time", day: 15, hour: 4,
                                                      next_click: ".work_job_reminders_note input")
        fill_in("Note", with: "Go to town")
      end

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
      click_button("Save")

      expect_success
      within(all("table.index tr")[1]) do
        expect(page).to have_css("td.title", text: "AAA Painter")
        expect(page).to have_css("td.slots", text: 6)
      end
      click_link("AAA Painter")

      # Check for reminders, edit one, remove one.
      within(all(".work_job_reminders .nested-fields")[0]) do
        expect(page).to have_selector("input[value='Go to town']")
        find("a.remove_fields").click
      end
      within(all(".work_job_reminders .nested-fields")[0]) do
        expect(page).to have_selector("input[value='Clean the lint trap']")
        find(".work_job_reminders_rel_magnitude input").set("3.5")
      end

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
      click_button("Save")

      expect_success
      within(all("table.index tr")[1]) do
        expect(page).to have_css("td.slots", text: 8)
      end
      click_link("AAA Painter")

      # Check for correct reminders.
      expect(page).not_to have_selector("input[value='Go to town']")
      expect(page).to have_selector("input[value='Clean the lint trap']")
      expect(all(".work_job_reminders .nested-fields").size).to eq(1)
    end

    scenario "delete" do
      visit(edit_work_job_path(jobs.first))
      accept_confirm { click_on("Delete") }
      expect_success
      expect(page).not_to have_content(jobs.first.title)
    end

    context "as regular user" do
      include_context "reminders"

      let(:actor) { create(:user) }
      let(:one_week_hence) { Time.zone.now + 7.days }
      let!(:job) { create(:work_job, period: periods[0], shift_count: 2) }
      let!(:reminder1) { create_work_job_reminder(job, one_week_hence) }
      let!(:reminder2) { create_work_job_reminder(job, 1, "days_before", note: "Sharpen the knife") }
      let!(:assignments1) { create_list(:work_assignment, 3, shift: job.shifts[0]) }
      let!(:assignments2) { create_list(:work_assignment, 3, shift: job.shifts[1]) }

      scenario "show" do
        visit(work_jobs_path)
        click_on(job.title)
        expect(page).to have_content(job.title)
        expect(page).to have_content("At #{I18n.l(one_week_hence)}")
        expect(page).to have_content(/1 day before: Sharpen the knife/)
        (assignments1 + assignments2).map(&:user).each do |user|
          expect(page).to have_content(user.name)
        end
      end
    end
  end
end
