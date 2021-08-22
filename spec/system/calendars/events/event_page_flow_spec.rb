# frozen_string_literal: true

require "rails_helper"

describe "event page flow", js: true do
  let(:user) { create(:user) }
  let!(:calendar1) { create(:calendar, name: "Foo Room", selected_by_default: true) }
  let!(:calendar2) { create(:calendar, name: "Bar Room", selected_by_default: true) }
  let!(:event) do
    create(:event, name: "Fun Event", calendar: calendar1,
                   starts_at: Time.current.midnight + 8.hours, creator: user)
  end

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  describe "create" do
    scenario "via combined view and create event button" do
      visit(calendars_events_path)
      click_on("Create Event")
      click_link("Bar Room")
      expect(page).to have_title("Bar Room: Create Event")

      # Redirects back to combined view after create.
      fill_and_save
      expect(page).to have_title("Events & Reservations")
    end

    describe "via combined view and click grid" do
      context "with existing reservable calendar" do
        scenario do
          visit(calendars_events_path)
          all('tr[data-time="11:30:00"] td.fc-widget-content')[-1].click
          expect(page).to have_content(/Create event on.+11:30 am to 12:00 pm/)
          click_on("OK")
          click_link("Bar Room")
          expect(page).to have_title("Bar Room: Create Event")
          expect(page).to have_field("Start Time", with: /11:30/)
        end
      end

      context "without existing reservable calendar" do
        let(:community) { create(:community) }
        let(:user) { create(:admin, community: community) }

        scenario do
          visit(calendars_events_path)
          all('tr[data-time="11:30:00"] td.fc-widget-content')[-1].click
          expect(page).to have_content(/Create event on.+11:30 am to 12:00 pm/)
          click_on("OK")
          expect(page).to have_content("does not have any calendars")
          click_on("You can create one")
          expect(page).to have_title("Calendars")
        end
      end
    end

    scenario "via single calendar view" do
      visit(calendars_events_path(calendar_id: calendar1.id))
      click_on("Create Event")
      expect(page).to have_title("Foo Room: Create Event")

      # Redirects back to single calendar view after create.
      fill_and_save
      expect(page).to have_title("Foo Room")
    end

    def fill_and_save
      fill_in("Event Name", with: "stuff")
      click_on("Save")
      expect_success
    end
  end

  describe "edit" do
    scenario "from combined view" do
      visit(calendars_events_path)
      show_edit_and_save
      expect(page).to have_title("Events & Reservations")
    end

    scenario "from single calendar view" do
      visit(calendars_events_path(calendar_id: calendar1.id))
      show_edit_and_save
      expect(page).to have_title("Foo Room")
    end

    def show_edit_and_save
      find("div.fc-title", text: "Fun Event").click
      click_on("Edit")
      fill_in("Event Name", with: "Fun Event Delta")
      click_on("Save")
      expect_success
    end
  end

  describe "destroy" do
    scenario "from combined view" do
      visit(calendars_events_path)
      show_and_destroy
      expect(page).to have_title("Events & Reservations")
    end

    scenario "from single calendar view" do
      visit(calendars_events_path(calendar_id: calendar1.id))
      show_and_destroy
      expect(page).to have_title("Foo Room")
    end

    def show_and_destroy
      find("div.fc-title", text: "Fun Event").click
      accept_confirm { click_on("Cancel") }
      expect_success
    end
  end
end
