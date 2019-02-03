# frozen_string_literal: true

FactoryBot.define do
  factory :work_job_reminder, class: "Work::JobReminder" do
    association :job, factory: :work_job
    note { "Do stuff" }
    abs_rel { "absolute" }

    after(:build) do |reminder|
      reminder.abs_time ||= "2018-01-01 12:00" if reminder.abs_rel == "absolute"
    end
  end
end
