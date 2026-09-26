# frozen_string_literal: true

require "rails_helper"

# The scope choices and the rows each one writes are covered in
# spec/forms/calendars/eventlet_deletion_form_spec.rb; this spec exercises the show page's delete
# modal end to end, checking the result on the calendar grid.
describe "deleting a recurring or multi-calendar event", js: true do
  let(:user) { create(:user) }
  let!(:calendar) { create(:calendar, name: "Main Hall") }
  let(:calendar2) { create(:calendar, name: "Guest Room") }

  # Weekly on Mondays at 10am, starting next week, so each occurrence sits in its own week.
  let(:series_start) { Time.current.next_week.midnight + 10.hours }
  let(:rule) { IceCube::Rule.weekly.to_hash }
  let!(:event) do
    create(:event, name: "Weekly Event", calendar: calendar, creator: user, recurrence_rule: rule,
      starts_at: series_start, ends_at: series_start + 1.hour)
  end
  let(:eventlet) { event.eventlets.detect { |e| e.calendar_id == calendar.id } }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  def occ(n)
    series_start + n.weeks
  end

  def visit_occurrence(n)
    visit(calendars_eventlet_path(eventlet, occurrence: occ(n).to_i))
    expect(page).to have_title("Event: Weekly Event")
  end

  def expect_on_grid(n, present:, on: calendar)
    visit(calendar_events_path(on, date: occ(n).to_date.to_fs(:no_time)))
    matcher = present ? :have_css : :have_no_css
    expect(page).to send(matcher, "div.fc-title", text: "Weekly Event")
  end

  context "with a series on one calendar" do
    scenario "deleting only this occurrence" do
      visit_occurrence(1)
      click_on("Delete")
      expect_modal(title: "Delete recurring event", text: "'Weekly Event' repeats")
      click_modal_button("Only this occurrence")

      expect(page).to have_success_alert("The occurrence was deleted.")
      expect(page).to have_no_css("div.fc-title", text: "Weekly Event")
      expect_on_grid(2, present: true)
    end

    scenario "deleting this and following occurrences" do
      visit_occurrence(1)
      click_on("Delete")
      click_modal_button("This and following")

      expect(page).to have_success_alert("This and all following occurrences of the event were deleted.")
      expect_on_grid(2, present: false)
      expect_on_grid(0, present: true)
    end

    scenario "deleting all occurrences" do
      visit_occurrence(1)
      click_on("Delete")
      click_modal_button("All occurrences")

      expect(page).to have_success_alert("All occurrences of the event were deleted.")
      expect_on_grid(0, present: false)
    end

    scenario "cancelling leaves the series alone" do
      visit_occurrence(1)
      click_on("Delete")
      click_modal_button(I18n.t("modal.cancel"))

      expect_no_modal
      expect(page).to have_title("Event: Weekly Event")
      expect_on_grid(1, present: true)
    end
  end

  context "with a series that has already started" do
    let(:series_start) { 2.weeks.ago.midnight + 10.hours }

    before do
      event.update_columns(created_at: 1.month.ago)
      eventlet.update_columns(created_at: 1.month.ago)
    end

    scenario "the creator is only offered what they may delete" do
      visit_occurrence(3)
      click_on("Delete")
      expect_modal(title: "Delete recurring event")
      with_top_level_scope do
        within("#{modal_selector} .modal-footer") do
          expect(page).to have_button("Only this occurrence")
          expect(page).to have_button("This and following")
          expect(page).to have_no_button("All occurrences")
        end
      end
    end
  end

  context "with a series on two calendars" do
    before { event.eventlets.create!(calendar: calendar2) }

    scenario "deleting one occurrence from this calendar only" do
      visit_occurrence(1)
      click_on("Delete")
      expect_modal(title: "Delete multi-calendar event", text: "Guest Room")
      click_modal_button("Delete only from Main Hall")
      expect_modal(title: "Delete recurring event", text: "deleted from Main Hall")
      click_modal_button("Only this occurrence")

      expect(page).to have_success_alert("The occurrence was removed from Main Hall.")
      expect(page).to have_no_css("div.fc-title", text: "Weekly Event")
      expect_on_grid(1, present: true, on: calendar2)
    end
  end

  context "with a non-recurring event on two calendars" do
    let(:rule) { nil }

    before { event.eventlets.create!(calendar: calendar2) }

    scenario "only the calendar question is asked" do
      visit(calendars_eventlet_path(eventlet))
      click_on("Delete")
      expect_modal(title: "Delete multi-calendar event")
      click_modal_button("Delete from all calendars")

      expect(page).to have_success_alert("Event deleted successfully.")
      expect_on_grid(0, present: false, on: calendar2)
    end
  end
end
