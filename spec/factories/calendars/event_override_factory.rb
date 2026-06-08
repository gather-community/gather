# frozen_string_literal: true

FactoryBot.define do
  factory :event_override, class: "Calendars::EventOverride" do
    association :event, factory: :event
    # occurrence_start must be set to a valid occurrence of the event's series.
    # Callers are responsible for providing a recurring event and a valid occurrence_start.
    occurrence_start { nil }
    deleted { false }
    starts_at { nil }
    ends_at { nil }
  end
end
