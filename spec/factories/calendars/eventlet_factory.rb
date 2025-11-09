# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_eventlets
#
#  id          :bigint           not null, primary key
#  cluster_id  :bigint           not null
#  event_id    :bigint           not null
#  calendar_id :bigint           not null
#  all_day     :boolean          default(FALSE), not null
#  starts_at   :datetime         not null
#  ends_at     :datetime         not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :eventlet, class: "Calendars::Eventlet" do
    transient do
      creator { nil }
      group { nil }
    end

    event do |evaluator|
      overrides = {
        calendar: calendar,
        starts_at: starts_at,
        ends_at: ends_at
      }
      overrides[:creator] = evaluator.creator if evaluator.creator.present?
      overrides[:group] = evaluator.group if evaluator.group.present?
      overrides[:dont_sync_eventlet] = true
      association :event, overrides
    end

    calendar
    starts_at { Time.current.tomorrow.midnight }
    ends_at { starts_at + 55.minutes }
  end
end
