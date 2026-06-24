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
