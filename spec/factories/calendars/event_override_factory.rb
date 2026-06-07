# frozen_string_literal: true

FactoryBot.define do
  factory :event_override, class: "Calendars::EventOverride" do
    eventlet
    # occurrence_start must be set to a valid occurrence of the eventlet's event.
    # Since EventOverride requires a recurring event, callers should use a recurring eventlet.
    occurrence_start { nil }
    deleted { false }
    starts_at { nil }
    ends_at { nil }
  end
end
