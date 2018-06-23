# frozen_string_literal: true

FactoryBot.define do
  factory :work_reminder, class: "Work::Reminder" do
    association :job, factory: :work_job
    note "Do stuff"
  end
end
