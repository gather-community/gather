require "rails_helper"

feature "periods", js: true do
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

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  scenario "index" do
    visit(work_periods_path)
    expect(page).to have_title("Work Periods")
    expect(page).to have_css("table.index tr", count: 4) # Header plus two rows
    expect(page).to have_css("table.index tr td.name", text: "Foo")
  end
end
