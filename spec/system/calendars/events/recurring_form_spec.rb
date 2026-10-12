# frozen_string_literal: true

require "rails_helper"

# Creating and editing repeating events in the event form. See Calendars::EventForm; the form logic
# itself is covered in event_form_spec.rb.
describe "repeating events in the event form", js: true do
  let(:community) { create(:community) }
  let(:user) { create(:user, community: community) }
  let(:calendar) { create(:calendar, community: community, name: "Courtyard", allow_overlap: true) }
  # Mondays at 6pm, starting next week.
  let(:start) { Time.zone.now.next_week.midnight + 18.hours }

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  def wk(n)
    start + n.weeks
  end

  def visible?(label)
    page.has_field?(label, visible: true, wait: 0.5)
  end

  scenario "creating a weekly series, with only the fields that apply shown" do
    visit(new_calendar_event_path(calendar, start: start.strftime("%Y-%m-%d %H:%M"),
      end: (start + 1.hour).strftime("%Y-%m-%d %H:%M")))
    fill_in("Event Name", with: "Book club")

    expect(visible?("Every")).to be(false)
    select("Weekly", from: "Repeats")
    expect(visible?("Every")).to be(true)
    expect(visible?("On")).to be(false)
    expect(page).to have_css(".calendars_event_repeat_interval .hint", text: "week")

    fill_in("Every", with: "2")
    expect(page).to have_css(".calendars_event_repeat_interval .hint", text: "weeks")

    select("Monthly", from: "Repeats")
    expect(visible?("On")).to be(true)
    select("Weekly", from: "Repeats")

    expect(visible?("Number of times")).to be(false)
    select("After a number of times", from: "Ends")
    expect(visible?("Number of times")).to be(true)
    fill_in("Number of times", with: "3")
    click_on("Save")

    expect_success
    event = Calendars::Event.find_by!(name: "Book club")
    expect(event.schedule.first(10).map(&:to_time)).to eq([wk(0), wk(2), wk(4)])
  end

  context "on a calendar that doesn't allow repeating events" do
    let(:calendar) { create(:calendar, community: community, allow_overlap: false) }

    scenario "explains why instead of showing repeat settings" do
      visit(new_calendar_event_path(calendar))
      expect(page).not_to have_field("Repeats")
      expect(page).to have_content(
        "Repeating events aren't available on this calendar because events on it can't overlap."
      )
    end
  end

  context "with a series" do
    let!(:event) do
      create(:event, calendar: calendar, creator: user, name: "Book club", starts_at: start,
        ends_at: start + 1.hour, recurrence_rule: IceCube::Rule.weekly.day(start.wday).to_hash).tap do |e|
        e.update_columns(created_at: 1.week.ago)
        e.eventlets.update_all(created_at: 1.week.ago)
      end
    end

    def open_edit_from(occurrence)
      visit(calendars_eventlet_path(event.eventlets.first, occurrence: occurrence.to_i))
      click_on("Edit")
    end

    scenario "changing this and following from a later occurrence" do
      open_edit_from(wk(2))
      expect(page).to have_content("Opened from the occurrence on #{I18n.l(wk(2).to_date, format: :long)}")
      choose("This and following occurrences")
      fill_in("Event Name", with: "Reading group")
      click_on("Save")

      expect_success
      expect(event.reload.name).to eq("Book club")
      expect(event.schedule.first(10).map(&:to_time)).to eq([wk(0), wk(1)])
      split_off = Calendars::Event.where.not(id: event.id).sole
      expect(split_off.name).to eq("Reading group")
      expect(split_off.starts_at).to eq(wk(2))
    end

    scenario "refusing a change to the days it repeats on when an occurrence was deleted" do
      create(:event_override, event: event, occurrence_start: wk(3), deleted: true)
      open_edit_from(wk(1))
      choose("All occurrences")
      select("Daily", from: "Repeats")
      click_on("Save")

      expect_validation_error
      expect(page).to have_content("1 occurrence in the part being changed has been moved or deleted")
      expect(event.reload.schedule.first(2).map(&:to_time)).to eq([wk(0), wk(1)])
    end

    scenario "deleting from the edit page asks which occurrences" do
      open_edit_from(wk(2))
      click_on("Delete")
      expect(page).to have_css(modal_selector, text: "Which occurrences should be deleted?")
      click_modal_button("This only")

      expect(page).to have_css("div.alert-success", text: "The occurrence was deleted.")
      expect(event.event_overrides.reload.sole.occurrence_start).to eq(wk(2))
    end

    context "once it has started" do
      before { Timecop.travel(start + 1.day) }
      after { Timecop.return }

      scenario "offers only this and following from a future occurrence" do
        open_edit_from(wk(2))
        expect(page).to have_field("This and following occurrences")
        expect(page).not_to have_field("All occurrences")
      end

      scenario "explains that a past occurrence can't change the series" do
        open_edit_from(wk(0))
        expect(page).not_to have_field("This and following occurrences")
        expect(page).to have_content("This series can't be changed from this occurrence.")
      end
    end
  end
end
