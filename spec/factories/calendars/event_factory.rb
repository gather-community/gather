# frozen_string_literal: true

FactoryBot.define do
  factory :event, class: "Calendars::Event" do
    name { "Fun times" }
    calendar
    association :creator, factory: :user
    sequence(:starts_at) { |n| Time.current.tomorrow.midnight + n.hours }
    sequence(:ends_at) { starts_at + 55.minutes }
    kind { nil }
  end
end
