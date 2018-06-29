# frozen_string_literal: true

FactoryBot.define do
  factory :work_reminder, class: "Work::Reminder" do
    association :job, factory: :work_job
    note "Do stuff"

    after(:build) do |reminder|
      if reminder.abs_rel.blank?
        reminder.abs_rel = "absolute"
        reminder.abs_time = "2018-01-01 12:00"
      end
    end
  end
end
