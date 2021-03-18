# frozen_string_literal: true

require "rails_helper"

describe "event form" do
  let(:user) { create(:user) }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  context "with pre_notice" do
    let(:calendar) { create(:calendar) }
    let!(:protocol) { create(:calendar_protocol, calendars: [calendar], pre_notice: "May be bed bugs!") }

    scenario "should show warning" do
      visit new_calendars_event_path(calendar_id: calendar.id)
      expect(page).to have_content("May be bed bugs!")
    end
  end
end
