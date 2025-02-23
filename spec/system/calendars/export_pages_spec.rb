# frozen_string_literal: true

require "rails_helper"

describe "calendar export pages", js: true do
  let(:user_token) { "z8-fwETMhx93t9nxkeQ_" }
  let(:cmty_token) { "mYfEv68-_HG4_lrfGGre" }
  let!(:user) { create(:user, calendar_token: user_token) }

  before do
    Defaults.community.update!(calendar_token: cmty_token)
    login_as(user, scope: :user)
    use_user_subdomain(user)
  end

  describe "export link" do
    context "from calendar home page" do
      let!(:calendar1) { create(:calendar, name: "Calendar 1") }
      let!(:calendar2) { create(:calendar, name: "Calendar 2") }
      let!(:calendar3) { create(:calendar, name: "Calendar 3") }

      scenario do
        visit("/calendars/events")
        check("Calendar 1")
        check("Calendar 3")
        expect(page).not_to have_loading_indicator

        click_on("Export")
        expect(page).to have_field("Calendar 1", checked: true)
        expect(page).to have_field("Calendar 2", checked: false)
        expect(page).to have_field("Calendar 3", checked: true)
        expect(page).to have_field("export-url", with: "webcal://default.gatherdev.org:31337" \
                                                       "/calendars/export.ics?calendars=#{calendar1.id}+#{calendar3.id}&token=#{user_token}")

        # Single calendar
        uncheck("Calendar 1")
        expect(page).to have_field("export-url", with: "webcal://default.gatherdev.org:31337" \
                                                       "/calendars/export.ics?calendars=#{calendar3.id}&token=#{user_token}")

        # All calendars
        check("Calendar 1")
        check("Calendar 2")
        expect(page).to have_field("export-url", with: "webcal://default.gatherdev.org:31337" \
                                                       "/calendars/export.ics?calendars=all&token=#{user_token}")

        check("Include only your events")
        expect(page).to have_field("export-url", with: "webcal://default.gatherdev.org:31337" \
                                                       "/calendars/export.ics?calendars=all&token=#{user_token}&own_only=1")

        check("Don't personalize events")
        expect(page).not_to have_content("Include only events you created")
        expect(page).to have_field("export-url", with: "webcal://default.gatherdev.org:31337" \
                                                       "/calendars/community-export.ics?calendars=all&token=#{cmty_token}")
      end
    end

    context "from single calendar page" do
      let!(:calendar1) { create(:calendar, name: "Calendar 1") }
      let!(:calendar2) { create(:calendar, name: "Calendar 2") }

      scenario do
        visit(calendar_events_path(calendar1))
        click_on("Export")

        expect(page).to have_field("Calendar 1", checked: true)
        expect(page).to have_field("Calendar 2", checked: false)
        expect(page).to have_field("export-url", with: "webcal://default.gatherdev.org:31337" \
                                                       "/calendars/export.ics?calendars=#{calendar1.id}&token=#{user_token}")
      end
    end
  end

  scenario "reset_token" do
    visit("/calendars/exports")
    expect(page).to have_field("export-url", with: "webcal://default.gatherdev.org:31337" \
                                                   "/calendars/export.ics?calendars=all&token=#{user_token}")
    expect(find("#export-url").value.match(/token=(.+)$/)[1]).to eq(user_token)

    click_link("click here to reset your secret token")
    expect(page).to have_content("Token reset successfully")
    expect(find("#export-url").value.match(/token=(.+)$/)[1]).not_to eq(user_token)
  end
end
