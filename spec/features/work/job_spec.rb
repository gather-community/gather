require "rails_helper"

feature "jobs", js: true do
  let(:actor) { create(:work_coordinator) }
  let(:period) { create(:work_period) }
  let!(:groups) { create_list(:people_group, 2) }
  let!(:jobs) do
    [create(:work_job, period: period), create(:work_job, period: period, slot_type: "full_single")]
  end

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "index" do
    visit(work_jobs_path)
    expect(page).to have_title("Jobs")
    expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
  end

  scenario "create, show, and update" do
    visit(work_jobs_path)
    click_link("Create")
    fill_in("Title", with: "AAA Painter")
    fill_in("Hours", with: "2")
    select(groups.first.name, from: "Requester")
    fill_in("Description", with: "Paints things nicely")
    within(all("#shift-rows tr")[0]) do
      pick_datetime(".starts-at", day: 15, hour: 4, next_click: "input.shift-slots")
      pick_datetime(".ends-at", day: 15, hour: 6, next_click: "input.shift-slots")
      find(".shift-slots").set(2)
    end
    click_on("Add Shift")
    within(all("#shift-rows tr")[1]) do
      pick_datetime(".starts-at", day: 15, hour: 5, next_click: "input.shift-slots")
      pick_datetime(".ends-at", day: 15, hour: 7, next_click: "input.shift-slots")
      find(".shift-slots").set(4)
    end
    click_on("Create Job")

    expect_success
    within(all("table.index tr")[1]) do
      expect(page).to have_css("td.title", text: "AAA Painter")
      expect(page).to have_css("td.slots", text: 6)
    end
    click_link("AAA Painter")

    all("#shift-rows tr")[1].find("a.remove_fields").click
    click_on("Add Shift")
    within(all("#shift-rows tr")[1]) do
      pick_datetime(".starts-at", day: 15, hour: 9, next_click: "input.shift-slots")
      pick_datetime(".ends-at", day: 15, hour: 11, next_click: "input.shift-slots")
      find(".shift-slots").set(6)
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
