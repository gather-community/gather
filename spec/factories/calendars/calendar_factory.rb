# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  cluster_id            :integer          not null
#  color                 :string(7)
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  group_id              :bigint
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  updated_at            :datetime         not null
#
FactoryBot.define do
  factory :calendar, class: "Calendars::Calendar" do
    sequence(:name) { |n| "Calendar #{n}" }
    sequence(:abbrv) { |n| "C#{n}" }
    community { Defaults.community }
    sequence(:color) { |n| "##{n.to_s.ljust(6, '0')}" }
    allow_overlap { false } # DB default is true now but many specs assume false

    trait :inactive do
      deactivated_at { Time.current - 1 }
    end

    trait :with_shared_guidelines do
      guidelines { "Guideline 1" }

      after(:build) do |calendar|
        calendar.shared_guidelines.build(community: calendar.community, name: "Foo", body: "Guideline 2")
        calendar.shared_guidelines.build(community: calendar.community, name: "Bar", body: "Guideline 3")
      end
    end
  end
end
