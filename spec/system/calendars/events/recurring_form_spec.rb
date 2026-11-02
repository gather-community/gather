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
    expect(page).to have_css(".repeat-interval", text: "week")

    fill_in("Every", with: "2")
    expect(page).to have_css(".repeat-interval", text: "weeks")

    select("Monthly", from: "Repeats")
    expect(visible?("On")).to be(true)
    select("Weekly", from: "Repeats")

    # The end date picker is a date only, unlike the start and end time pickers.
    select("On a date", from: "Ends")
    format = page.evaluate_script("$('.calendars_event_repeat_ends_on .datetimepicker')" \
      ".data('DateTimePicker').format()")
    expect(format).not_to match(/h:/i)

    expect(visible?("Number of Times")).to be(false)
    select("After a number of times", from: "Ends")
    expect(visible?("Number of Times")).to be(true)
    fill_in("Number of Times", with: "3")
    click_on("Save")

    expect_success
    event = Calendars::Event.find_by!(name: "Book club")
    expect(event.schedule.first(10).map(&:to_time)).to eq([wk(0), wk(2), wk(4)])
  end

  describe "choices that follow the start date" do
    # The fourth Monday of February 2027, which is also the last.
    let(:start) { Time.zone.local(2027, 2, 22, 18) }

    # The end follows the start (calendars--event-form#moveEnd).
    def move_start_to(time)
      page.execute_script("$('.calendars_event_starts_at .datetimepicker').data('DateTimePicker')" \
        ".date(moment('#{time.strftime("%Y-%m-%dT%H:%M")}'))")
    end

    def weekday_box(wday)
      find("#calendars_event_repeat_weekdays_#{wday}")
    end

    def monthly_options
      all("#calendars_event_repeat_monthly_by option").map(&:text)
    end

    before do
      visit(new_calendar_event_path(calendar, start: start.strftime("%Y-%m-%d %H:%M"),
        end: (start + 1.hour).strftime("%Y-%m-%d %H:%M")))
      fill_in("Event Name", with: "Book club")
    end

    scenario "weekly: the start's weekday is locked, and moves with the start" do
      select("Weekly", from: "Repeats")
      expect(weekday_box(1)).to be_checked.and(be_disabled)
      weekday_box(3).check

      move_start_to(start + 1.day)
      expect(weekday_box(2)).to be_checked.and(be_disabled)
      expect(weekday_box(1)).not_to be_checked
      expect(weekday_box(1)).not_to be_disabled
      expect(weekday_box(3)).to be_checked
      click_on("Save")

      expect_success
      event = Calendars::Event.find_by!(name: "Book club")
      expect(event.schedule.first(3).map(&:to_time)).to eq([start + 1.day, start + 2.days, start + 8.days])
    end

    scenario "an empty end date opens on a month after the start, and a chosen one is kept" do
      select("Weekly", from: "Repeats")
      select("On a date", from: "Ends")
      # Monday March 1st, so it opens on April 1st.
      move_start_to(start + 1.week)
      find(".calendars_event_repeat_ends_on .input-group-btn button").click
      expect(find_field("End Date").value).to match(/Apr 0?1 2027/)

      find("body").click
      move_start_to(start + 2.weeks)
      find(".calendars_event_repeat_ends_on .input-group-btn button").click
      expect(find_field("End Date").value).to match(/Apr 0?1 2027/)
    end

    scenario "monthly: the choices are worded from the start, and follow it" do
      select("Monthly", from: "Repeats")
      expect(monthly_options).to eq(["Day 22", "The fourth Monday", "The last Monday"])

      # A fifth Tuesday, which can only be the last.
      move_start_to(Time.zone.local(2027, 3, 30, 18))
      expect(page).to have_select("On", options: ["Day 30", "The last Tuesday"])
      select("The last Tuesday", from: "On")
      click_on("Save")

      expect_success
      event = Calendars::Event.find_by!(name: "Book club")
      expect(event.schedule.first(2).map(&:to_date)).to eq([Date.new(2027, 3, 30), Date.new(2027, 4, 27)])
    end
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

    def move_start_by(amount)
      time = wk(2) + amount
      page.execute_script("$('.calendars_event_starts_at .datetimepicker').data('DateTimePicker')" \
        ".date(moment('#{time.strftime("%Y-%m-%dT%H:%M")}'))")
    end

    scenario "changing from a later occurrence, with a note that it applies from there" do
      open_edit_from(wk(2))
      expect(page).not_to have_field("Change")
      expect(page).to have_content("Any changes made below apply only from #{I18n.l(wk(2).to_date)} onward.")
      expect(page).to have_link(I18n.l(wk(0).to_date))
      fill_in("Event Name", with: "Reading group")
      move_start_by(1.hour)
      click_on("Save")

      expect_success
      expect(event.reload.name).to eq("Book club")
      expect(event.schedule.first(10).map(&:to_time)).to eq([wk(0), wk(1)])
      split_off = Calendars::Event.where.not(id: event.id).sole
      expect([split_off.name, split_off.starts_at]).to eq(["Reading group", wk(2) + 1.hour])
    end

    scenario "the note's link opens the first upcoming occurrence" do
      open_edit_from(wk(2))
      click_on(I18n.l(wk(0).to_date))
      expect(page).to have_field("Start Time", with: /#{wk(0).strftime("%b")}/)
      expect(page).not_to have_content("Any changes made below")
    end

    scenario "refusing a change to the days it repeats on when an occurrence was deleted" do
      create(:event_override, event: event, occurrence_start: wk(3), deleted: true)
      open_edit_from(wk(1))
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

      scenario "lets the times change from a future occurrence" do
        open_edit_from(wk(2))
        expect(page).to have_field("Start Time", disabled: false)
      end

      scenario "disables the whole form from a past occurrence" do
        open_edit_from(wk(0))
        expect(page).to have_field("Event Name", disabled: true)
        expect(page).to have_field("Start Time", disabled: true)
        expect(page).to have_field("Repeats", disabled: true)
        expect(page).to have_no_button("Save")
        expect(page).to have_content("This occurrence has already begun, so it can't be changed.")
        expect(page).to have_link(I18n.l(wk(1).to_date))
      end
    end
  end
end
