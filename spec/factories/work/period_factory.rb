# frozen_string_literal: true

# == Schema Information
#
# Table name: work_periods
#
#  id                    :bigint           not null, primary key
#  auto_open_time        :datetime
#  cluster_id            :integer          not null
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  ends_on               :date             not null
#  max_rounds_per_worker :integer
#  meal_job_requester_id :bigint
#  meal_job_sync         :boolean          default(FALSE), not null
#  name                  :string           not null
#  phase                 :string           default("draft"), not null
#  pick_type             :string           default("free_for_all"), not null
#  quota                 :decimal(10, 2)   default(0.0), not null
#  quota_type            :string           default("none"), not null
#  round_duration        :integer
#  starts_on             :date             not null
#  updated_at            :datetime         not null
#  workers_per_round     :integer
#
FactoryBot.define do
  factory :work_period, class: "Work::Period" do
    transient do
      meal_job_sync_setting_pairs { [] }
    end

    sequence(:name) { |n| "#{Faker::Lorem.word.capitalize} #{n}" }
    starts_on { Date.new(2018, 1, 1) }
    ends_on { starts_on + 30.days }
    community { Defaults.community }
    pick_type { "free_for_all" }

    after(:build) do |period, evaluator|
      evaluator.meal_job_sync_setting_pairs.each do |pair|
        period.meal_job_sync_settings.build(formula: pair[0], role: pair[1])
      end
    end

    trait :with_shares do
      after(:create) do |period|
        User.in_community(period.community).adults.active.each do |u|
          period.shares.create!(user: u, portion: [0, 0, 0.25, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1, 1, 1].sample)
        end
      end
    end
  end
end
