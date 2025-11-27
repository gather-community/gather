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
    association(:event, strategy: :build)
    calendar
    sequence(:starts_at) { |n| Time.current.tomorrow.midnight + n.hours }
    sequence(:ends_at) { starts_at + 55.minutes }

    after(:build) do |eventlet|
      eventlet.event.eventlets << eventlet
      eventlet.event.calendar = eventlet.calendar
    end
  end
end
