# frozen_string_literal: true

require "rails_helper"

describe "calendar eventlet show page" do
  let(:community) { create(:community) }
  let!(:user) { create(:user, community: community) }
  let!(:calendar) { create(:calendar, community: community) }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  context "with a non-recurring event" do
    let!(:event) do
      create(:event, calendar: calendar, creator: user, name: "Solo Event",
        starts_at: "2026-06-18 10:00", ends_at: "2026-06-18 11:00")
    end
    let(:eventlet) { event.eventlets.first }

    it "renders the eventlet show page without a recurrence row" do
      get(calendars_eventlet_path(eventlet))
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Solo Event")
      expect(response.body).not_to include("Repeats")
    end

    it "404s when given a stray occurrence param" do
      expect do
        get(calendars_eventlet_path(eventlet, occurrence: Time.zone.parse("2026-06-18 10:00").to_i))
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "with a recurring event" do
    # Weekly from Wednesday 2026-06-03 14:00. 2026-06-17 14:00 is a valid occurrence.
    let!(:event) do
      create(:event, calendar: calendar, creator: user, name: "Weekly Event",
        starts_at: "2026-06-03 14:00", ends_at: "2026-06-03 15:00",
        recurrence_rule: IceCube::Rule.weekly.to_hash)
    end
    let(:eventlet) { event.eventlets.first }
    let(:occ) { Time.zone.parse("2026-06-17 14:00") }

    it "renders the clicked occurrence with the recurrence description" do
      get(calendars_eventlet_path(eventlet, occurrence: occ.to_i))
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Weekly Event")
      expect(response.body).to include("Repeats")
      expect(response.body).to include("Jun 17")
    end

    it "defaults to the first occurrence when no occurrence param is given" do
      get(calendars_eventlet_path(eventlet))
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Jun 03")
    end

    it "404s for an occurrence that is not in the series" do
      expect do
        get(calendars_eventlet_path(eventlet, occurrence: Time.zone.parse("2026-06-18 14:00").to_i))
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "404s for an occurrence deleted by an EventOverride" do
      create(:event_override, event: event, occurrence_start: occ, deleted: true)
      expect do
        get(calendars_eventlet_path(eventlet, occurrence: occ.to_i))
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "404s for an occurrence deleted on this calendar by an EventletOverride" do
      eo = create(:event_override, event: event, occurrence_start: occ)
      create(:eventlet_override, event_override: eo, eventlet: eventlet, deleted: true)
      expect do
        get(calendars_eventlet_path(eventlet, occurrence: occ.to_i))
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "shows the moved time for a rescheduled occurrence" do
      create(:event_override, event: event, occurrence_start: occ,
        starts_at: Time.zone.parse("2026-06-18 09:00"), ends_at: Time.zone.parse("2026-06-18 10:00"))
      get(calendars_eventlet_path(eventlet, occurrence: occ.to_i))
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Jun 18")
    end
  end

  context "with a meal event" do
    let!(:calendar) { create(:calendar, community: community, meal_hostable: true) }
    let!(:meal) do
      create(:meal, :with_menu, community: community, calendars: [calendar], title: "Tasty Tacos").tap do |m|
        m.build_events
        m.save!
      end
    end
    let(:event) { meal.events.first }
    let(:eventlet) { event.eventlets.first }

    it "renders the meal title and a link to the meal" do
      get(calendars_eventlet_path(eventlet))
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Tasty Tacos")
      expect(response.body).to include(meal_path(meal))
    end
  end

  context "with the legacy event show URL" do
    let!(:event) do
      create(:event, calendar: calendar, creator: user,
        starts_at: "2026-06-18 10:00", ends_at: "2026-06-18 11:00")
    end

    it "redirects to the canonical eventlet page" do
      get(calendars_event_path(event))
      expect(response).to redirect_to(calendars_eventlet_path(event.eventlets.first))
    end

    it "preserves the occurrence param in the redirect" do
      get(calendars_event_path(event, occurrence: 1_234_567_890))
      expect(response).to redirect_to(
        calendars_eventlet_path(event.eventlets.first, occurrence: 1_234_567_890)
      )
    end
  end
end

describe "calendar eventlet drag update" do
  let(:community) { create(:community) }
  let!(:user) { create(:user, community: community) }
  let!(:calendar) { create(:calendar, community: community, allow_overlap: true) }
  let(:starts_at) { Time.current.next_week.midnight + 12.hours }
  let!(:event) do
    create(:event, calendar: calendar, creator: user, starts_at: starts_at,
      ends_at: starts_at + 1.hour)
  end
  let(:eventlet) { event.eventlets.first }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  def drag(params)
    patch(calendars_eventlet_path(eventlet), params: {calendars_eventlet: params}, xhr: true)
  end

  it "moves the eventlet's offsets for a this-calendar drag" do
    drag(calendar_scope: "this", series_scope: "series",
      starts_at: (starts_at + 30.minutes).iso8601, ends_at: (starts_at + 90.minutes).iso8601)

    expect(response).to have_http_status(:ok)
    expect(eventlet.reload.start_offset).to eq(30.minutes.to_i)
    expect(event.reload.starts_at).to eq(starts_at)
  end

  it "moves the event for an all-calendars drag" do
    drag(calendar_scope: "all", series_scope: "series",
      starts_at: (starts_at + 2.hours).iso8601, ends_at: (starts_at + 3.hours).iso8601)

    expect(response).to have_http_status(:ok)
    expect(event.reload.starts_at).to eq(starts_at + 2.hours)
  end

  it "renders the error partial with a 422 when invalid" do
    drag(calendar_scope: "this", series_scope: "series",
      starts_at: (starts_at + 1.hour).iso8601, ends_at: starts_at.iso8601)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("must be after start time")
  end

  it "denies a user with no rights to the eventlet" do
    other = create(:user, community: create(:community))
    sign_in(other)
    expect do
      drag(calendar_scope: "this", series_scope: "series",
        starts_at: starts_at.iso8601, ends_at: (starts_at + 1.hour).iso8601)
    end.to raise_error(Pundit::NotAuthorizedError)
  end
end

describe "calendar eventlet delete" do
  let(:community) { create(:community) }
  let!(:user) { create(:user, community: community) }
  let!(:calendar) { create(:calendar, community: community, name: "Main Hall") }
  # Weekly at 6pm. Started two weeks ago and created long ago, so the creator can no longer delete
  # the whole series, only future occurrences.
  let(:series_start) { 2.weeks.ago.midnight + 18.hours }
  let!(:event) do
    create(:event, calendar: calendar, creator: user, name: "Weekly Event", starts_at: series_start,
      ends_at: series_start + 1.hour, recurrence_rule: IceCube::Rule.weekly.to_hash)
  end
  let(:eventlet) { event.eventlets.first }
  let(:future_occ) { series_start + 3.weeks }

  before do
    event.update_columns(created_at: 1.month.ago)
    eventlet.update_columns(created_at: 1.month.ago)
    use_user_subdomain(user)
    sign_in(user)
  end

  def delete_eventlet(origin_page: nil, **params)
    delete(calendars_eventlet_path(eventlet, origin_page: origin_page), params: {calendars_eventlet: params})
  end

  # Requests clear the tenant, so checks made afterward need it set again.
  def after_request(&block)
    ActsAsTenant.with_tenant(Defaults.cluster, &block)
  end

  it "deletes a future occurrence and returns to the calendar on its date" do
    delete_eventlet(calendar_scope: "all", series_scope: "occurrence", occurrence_start: future_occ.to_i)

    after_request do
      expect(event.event_overrides.sole).to have_attributes(deleted: true, occurrence_start: future_occ)
    end
    expect(response).to redirect_to(calendar_events_path(calendar, date: future_occ.to_date.to_fs(:no_time)))
    expect(flash[:success]).to eq("The occurrence was deleted.")
  end

  it "returns to the combined view when that's where the user came from" do
    delete_eventlet(origin_page: "combined", calendar_scope: "all", series_scope: "following",
      occurrence_start: future_occ.to_i)

    expect(response).to redirect_to(calendars_events_path(date: future_occ.to_date.to_fs(:no_time)))
    after_request { expect(event.reload.recurrence_end_date).to eq((future_occ - 1.week).to_date) }
  end

  it "refuses to let the creator delete a series that has started" do
    expect do
      delete_eventlet(calendar_scope: "all", series_scope: "series")
    end.to raise_error(Pundit::NotAuthorizedError)
    after_request { expect(Calendars::Event.exists?(event.id)).to be(true) }
  end

  it "refuses to let the creator delete a past occurrence" do
    expect do
      delete_eventlet(calendar_scope: "all", series_scope: "occurrence", occurrence_start: series_start.to_i)
    end.to raise_error(Pundit::NotAuthorizedError)
  end

  it "404s for an occurrence that was already deleted" do
    create(:event_override, event: event, occurrence_start: future_occ, deleted: true)
    expect do
      delete_eventlet(calendar_scope: "all", series_scope: "occurrence", occurrence_start: future_occ.to_i)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "shows an error for an invalid choice without deleting anything" do
    delete_eventlet(calendar_scope: "this", series_scope: "series")

    expect(flash[:error]).to eq("This event is only on one calendar")
    after_request { expect(Calendars::Event.exists?(event.id)).to be(true) }
  end

  it "doesn't let the old event delete route bypass the series rule" do
    expect do
      delete(calendars_event_path(event))
    end.to raise_error(Pundit::NotAuthorizedError)
    after_request { expect(Calendars::Event.exists?(event.id)).to be(true) }
  end
end
