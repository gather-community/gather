# frozen_string_literal: true

FactoryBot.define do
  factory :work_job, class: "Work::Job" do
    transient do
      shift_count 1
      shift_slots 3
      shift_hours nil
      shift_times []
    end

    association :period, factory: :work_period
    sequence(:title) { |n| "#{Faker::Job.title} #{n}" }
    hours 2
    description { Faker::Lorem.paragraph }

    before(:create) do |job, ev|
      if job.shifts.empty?
        (ev.shift_hours || [ev.hours_per_shift || ev.hours] * ev.shift_count).each_with_index do |hours, i|
          attribs = {
            job: job,
            hours: hours,
            slots: ev.shift_slots
          }
          attribs[:starts_at] = Time.zone.parse(ev.shift_times[i].to_s) if ev.shift_times[i]
          job.shifts << FactoryBot.build(:work_shift, attribs)
        end
      end
    end
  end
end
