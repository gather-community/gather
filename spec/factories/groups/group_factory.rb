# frozen_string_literal: true

FactoryBot.define do
  factory :group, class: "Groups::Group" do
    sequence(:name) { |n| "Group #{n}" }
    communities { [Defaults.community] }

    trait :inactive do
      deactivated_at { Time.current }
    end
  end
end
