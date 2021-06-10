# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_protocoling, class: "Calendars::Protocoling" do
    calendar
    protocol
  end
end
