# frozen_string_literal: true

FactoryBot.define do
  factory :eventlet, class: "Calendars::Eventlet" do
    event
    calendar
    sequence(:starts_at) { |n| Time.current.tomorrow.midnight + n.hours }
    sequence(:ends_at) { starts_at + 55.minutes }
  end
end
