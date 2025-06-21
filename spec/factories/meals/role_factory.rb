# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_roles
#
#  id                     :bigint           not null, primary key
#  cluster_id             :integer          not null
#  community_id           :integer          not null
#  count_per_meal         :integer          default(1), not null
#  created_at             :datetime         not null
#  deactivated_at         :datetime
#  description            :text             not null
#  double_signups_allowed :boolean          default(FALSE)
#  shift_end              :integer
#  shift_start            :integer
#  special                :string(32)
#  time_type              :string(32)       default("date_time"), not null
#  title                  :string(128)      not null
#  updated_at             :datetime         not null
#  work_hours             :decimal(6, 2)
#  work_job_title         :string(128)
#
FactoryBot.define do
  factory :meal_role, class: "Meals::Role" do
    sequence(:title) { |n| "#{Faker::Job.title} #{n}" }
    community { Defaults.community }
    time_type { "date_only" }
    description { Faker::Lorem.paragraph }

    trait :head_cook do
      special { "head_cook" }
      title { "Head Cook" }
    end

    trait :with_reminder do
      after(:build) do |role|
        role.reminders.build(build(:meal_role_reminder, role: role).attributes)
      end
    end

    trait :inactive do
      deactivated_at { Time.current - 1 }
    end
  end
end
