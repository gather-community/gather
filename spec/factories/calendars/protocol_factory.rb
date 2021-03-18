# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_protocol, class: "Calendars::Protocol" do
    transient do
      calendars { [] }
    end

    sequence(:name) { |i| "Protocol #{i}" }
    kinds { nil }
    community { calendars.first&.community || Defaults.community }

    after(:create) do |protocol, evaluator|
      protocol.calendars = evaluator.calendars
    end
  end
end
