# frozen_string_literal: true

FactoryBot.define do
  factory :group, class: "Groups::Group" do
    transient do
      joiners { [] }
    end

    sequence(:name) { |n| "Group #{n}" }
    communities { [Defaults.community] }

    trait :inactive do
      deactivated_at { Time.current }
    end

    after(:build) do |group, evaluator|
      evaluator.joiners.each do |joiner|
        group.memberships.build(user: joiner, kind: "joiner")
      end
    end
  end
end
