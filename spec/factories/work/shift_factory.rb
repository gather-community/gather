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
    ends_at { starts_at + (date_only ? 1.day : hours.hours) }
    slots 3
    association :job, factory: :work_job
  end
end
