# frozen_string_literal: true

FactoryBot.define do
  factory :group, class: "Groups::Group" do
    transient do
      joiners { [] }
      opt_outs { [] }
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
      evaluator.opt_outs.each do |opt_out|
        group.memberships.build(user: opt_out, kind: "opt_out")
      end
    end
  end
end
