# frozen_string_literal: true

require "rails_helper"

feature "report", js: true do
  include_context "work"

  let(:actor) { create(:user, first_name: "Donnell", last_name: "Corkery") }
  let(:report_path) { work_report_path(period: periods[0].id) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  it_behaves_like "handles no periods"

  context "with period but no jobs" do
    let!(:period) { create(:work_period) }

    scenario "index" do
      visit(report_path)
      expect(page).to have_content("0 0 0 Total Hours Jobs People")
    end
  end

  context "with data" do
    include_context "with jobs"
    include_context "with assignments"

    before do
      periods[0].update!(quota_type: "by_household")
      users.each { |u| periods[0].shares.create!(user: u, portion: 1) }
      Work::QuotaCalculator.new(periods[0]).recalculate_and_save
    end

    scenario "index" do
      visit(report_path)
      screenshot_and_open_image
      expect(page).to have_content("32 16 4 8 Total Hours Jobs People Quota")
      expect(page).to have_content("Donnell Corkery 6.0 75% 2.0")
      expect(page).to have_content("Churl Rox 0.0 0%")
      expect(page).to have_content(/Household\d+ 6.0 38% 2.0/)
    end
  end
end
