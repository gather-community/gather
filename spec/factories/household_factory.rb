# frozen_string_literal: true

# == Schema Information
#
# Table name: households
#
#  id             :integer          not null, primary key
#  alternate_id   :string
#  cluster_id     :integer          not null
#  community_id   :integer          not null
#  created_at     :datetime         not null
#  deactivated_at :datetime
#  garage_nums    :string
#  keyholders     :string
#  member_type_id :bigint
#  name           :string(50)       not null
#  unit_num       :integer
#  unit_suffix    :string
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :household do
    transient do
      member_count { 1 }
    end

    community { Defaults.community }
    sequence(:name) { |n| "Household#{n}" }

    trait :with_vehicles do
      after(:create) do |household|
        household.vehicles = create_list(:vehicle, rand(0..2), household: household)
      end
    end

    trait :with_emerg_contacts do
      after(:create) do |household|
        household.emergency_contacts = create_list(:emergency_contact, rand(0..2), household: household)
      end
    end

    trait :with_pets do
      after(:create) do |household|
        household.pets = create_list(:pet, rand(0..2), household: household)
      end
    end

    # NOTE: Don't try to assign FactoryBot created users directly to households as they already
    # have households and it doesn't work. Instead, create households first and then assign them to users.
    after(:create) do |household, evaluator|
      if household.users.empty?
        evaluator.member_count.times do
          household.users << create(:user, household: household)
        end
      end
    end
  end
end
