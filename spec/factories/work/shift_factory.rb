# frozen_string_literal: true

FactoryBot.define do
  factory :work_shift, class: "Work::Shift" do
    transient do
      hours 2
      date_only false
    end

    sequence(:starts_at) do |n|
      time = date_only ? "" : "9:00"
      Time.zone.parse("2018-01-01 #{time}") + n.days
    end
    sequence(:ends_at) do |n|
      time = date_only ? "" : "9:00"
      day = date_only ? n + 1 : n
      Time.zone.parse("2018-01-01 #{time}") + day.days + hours.hours
    end
    slots 3
    association :job, factory: :work_job
  end
end
