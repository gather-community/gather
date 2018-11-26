# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_export_event, class: "Calendars::Exports::Event" do
    sequence(:object_id) { |n| n }
    sequence(:starts_at) { |n| Time.current + n.hours}
    ends_at { starts_at + 55.minutes }
    location { Faker::Lorem.sentence.chomp(".") }
    summary { Faker::Lorem.sentence.chomp(".") }
    description { Faker::Lorem.sentence }
    url { "https://you.gather.coop/stuff/123" }
  end
end
