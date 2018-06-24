# frozen_string_literal: true

FactoryBot.define do
  factory :work_reminder, class: "Work::Reminder" do
    association :job, factory: :work_job
    note "Do stuff"

    after(:build) do |reminder|
      reminder.abs_time = "2018-01-01 12:00" if reminder.abs_time.blank? && reminder.rel_time.blank?
    end
  end
end
