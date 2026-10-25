# frozen_string_literal: true

FactoryBot.define do
  factory :eventlet_override, class: "Calendars::EventletOverride" do
    association :event_override, factory: :event_override
    association :eventlet, factory: :eventlet
    deleted { false }
    start_offset { nil }
    end_offset { nil }
  end
end
