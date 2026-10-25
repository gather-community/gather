# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_eventlets
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  event_id     :bigint           not null
#  calendar_id  :bigint           not null
#  start_offset :integer          not null, default: 0
#  end_offset   :integer          not null, default: 0
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :eventlet, class: "Calendars::Eventlet" do
    transient do
      name { nil }
      creator { nil }
      group { nil }
      note { nil }
      all_day { false }
      starts_at { Time.current.tomorrow.midnight }
      ends_at { starts_at + 55.minutes }
    end

    event do |evaluator|
      overrides = {
        calendar: calendar,
        starts_at: evaluator.starts_at,
        ends_at: evaluator.ends_at,
        all_day: evaluator.all_day
      }
      overrides[:name] = evaluator.name if evaluator.name.present?
      overrides[:creator] = evaluator.creator if evaluator.creator.present?
      overrides[:group] = evaluator.group if evaluator.group.present?
      overrides[:note] = evaluator.note if evaluator.note.present?
      overrides[:dont_sync_eventlet] = true
      association :event, overrides
    end

    calendar
    start_offset { 0 }
    end_offset { 0 }
  end
end
