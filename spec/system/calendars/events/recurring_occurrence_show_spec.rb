# frozen_string_literal: true

require "rails_helper"

# Status-code permutations (404 for invalid/deleted occurrences, the legacy /events/:id redirect) are
# covered in spec/requests/calendars/eventlets_request_spec.rb, because show_exceptions is disabled in
# the test env so a browser can't observe a 404. This spec exercises the real click-through flow.
describe "recurring occurrence show page", js: true do
  let(:user) { create(:user) }
  let!(:calendar) { create(:calendar, name: "Foo Room", selected_by_default: true) }

  # Weekly, anchored to 8am today, so exactly one occurrence (today) appears in the current week view.
  let!(:event) do
    create(:event, name: "Recurring Event", calendar: calendar, creator: user,
      starts_at: Time.current.midnight + 8.hours, ends_at: Time.current.midnight + 9.hours,
      recurrence_rule: IceCube::Rule.weekly.to_hash)
  end

  before do
    use_user_subdomain(user)
    login_as(user, scope: :user)
  end

  scenario "clicking an occurrence on the grid opens its occurrence page" do
    visit(calendar_events_path(calendar))
    find("div.fc-title", text: "Recurring Event").click

    # Lands on the eventlet show page for the specific occurrence.
    expect(page).to have_current_path(%r{/calendars/eventlets/\d+\?occurrence=\d+})
    expect(page).to have_title("Event: Recurring Event")

    # The recurrence pattern is shown subordinately, and the clicked occurrence's date is shown.
    expect(page).to have_content("Repeats")
    expect(page).to have_content("Weekly")
    # The first occurrence is today at 8am — shown via the same formatter the view uses.
    expect(page).to have_content(I18n.l(event.starts_at).squish)
  end
end
