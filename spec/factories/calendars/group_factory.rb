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
  factory :calendar_group, class: "Calendars::Group" do
    sequence(:name) { |n| "Calendar Group #{n}" }
    community { Defaults.community }

    trait :with_calendars do
      after(:build) do |group|
        2.times { group.calendars.build(build(:calendar).attributes) }
      end
    end
  end
end
