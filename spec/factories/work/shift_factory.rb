# frozen_string_literal: true

# == Schema Information
#
# Table name: work_shifts
#
#  id                :bigint           not null, primary key
#  assignments_count :integer          default(0), not null
#  cluster_id        :bigint           not null
#  created_at        :datetime         not null
#  ends_at           :datetime
#  job_id            :integer          not null
#  meal_id           :integer
#  slots             :integer          not null
#  starts_at         :datetime
#  updated_at        :datetime         not null
#
FactoryBot.define do
  factory :work_shift, class: "Work::Shift" do
    transient do
      hours { 2 }
      date_only { false }
    end

    sequence(:starts_at) do |n|
      time = date_only ? "" : "9:00"
      Time.zone.parse("2018-01-01 #{time}") + n.days
    end
    ends_at { starts_at + (date_only ? 1.day : hours.hours) }
    slots { 3 }
    association :job, factory: :work_job
  end
end
