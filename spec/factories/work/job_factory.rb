# frozen_string_literal: true

FactoryBot.define do
  factory :work_job, class: "Work::Job" do
    transient do
      shift_count { 1 }
      shift_slots { 3 }
      shift_hours { nil }
      shift_starts { [] }
      shift_ends { [] }
      meals { [] }
    end

    association :period, factory: :work_period
    sequence(:title) { |n| "#{Faker::Job.title} #{n}" }
    hours { 2 }
    description { Faker::Lorem.paragraph }

    before(:create) do |job, ev|
      if job.shifts.empty?
        (ev.shift_hours || [ev.hours_per_shift || ev.hours] * ev.shift_count).each_with_index do |hours, i|
          attribs = {
            job: job,
            hours: hours,
            slots: ev.shift_slots,
            meal: ev.meals[i]
          }
          if job.full_period?
            attribs[:starts_at] = Time.zone.parse(job.period.starts_on.to_s)
            attribs[:ends_at] = Time.zone.parse(job.period.ends_on.to_s)
          else
            attribs[:starts_at] = Time.zone.parse(ev.shift_starts[i].to_s) if ev.shift_starts[i]
            attribs[:ends_at] = Time.zone.parse(ev.shift_ends[i].to_s) if ev.shift_ends[i]
          end
          job.shifts << FactoryBot.build(:work_shift, attribs)
        end
      end
    end
  end
end
