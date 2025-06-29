# frozen_string_literal: true

FactoryBot.define do
  factory :eventlet, class: "Calendars::Eventlet" do
    association(:event, strategy: :build)
    calendar
    sequence(:starts_at) { |n| Time.current.tomorrow.midnight + n.hours }
    sequence(:ends_at) { starts_at + 55.minutes }

    after(:build) do |eventlet|
      eventlet.event.eventlets << eventlet
      eventlet.event.calendar = eventlet.calendar
    end
  end
end
