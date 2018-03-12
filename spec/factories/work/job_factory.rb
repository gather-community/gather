# frozen_string_literal: true

FactoryBot.define do
  factory :work_job, class: "Work::Job" do
    transient do
      shift_count 1
      shift_slots 3
      shift_hours nil
    end

    association :period, factory: :work_period
    title { Faker::Job.title }
    hours 2
    description { Faker::Lorem.paragraph }

    before(:create) do |job, ev|
      if job.shifts.empty?
        (ev.shift_hours || [ev.hours_per_shift || ev.hours] * ev.shift_count).each do |hours|
          job.shifts << FactoryBot.build(:work_shift,
            job: job,
            hours: hours,
            slots: ev.shift_slots)
        end
      end
    end
  end
end
