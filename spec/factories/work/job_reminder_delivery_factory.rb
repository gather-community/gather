# frozen_string_literal: true

FactoryBot.define do
  factory :work_job_reminder_delivery, class: "Work::JobReminderDelivery" do
    association :reminder, factory: :work_job_reminder
    association :shift, factory: :work_shift
    deliver_at { 1.day.from_now }
  end
end
