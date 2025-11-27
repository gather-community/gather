# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_events
#
#  id          :integer          not null, primary key
#  all_day     :boolean          default(FALSE), not null
#  calendar_id :integer          not null
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  creator_id  :integer
#  ends_at     :datetime         not null
#  group_id    :bigint
#  kind        :string
#  meal_id     :integer
#  name        :string(24)       not null
#  note        :text
#  sponsor_id  :integer
#  starts_at   :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :event, class: "Calendars::Event" do
    name { "Fun times" }
    calendar
    association :creator, factory: :user
    sequence(:starts_at) { |n| Time.current.tomorrow.midnight + n.hours }
    sequence(:ends_at) { starts_at + 55.minutes }
    kind { nil }
  end
end
