# frozen_string_literal: true

FactoryBot.define do
  factory :resource, class: "Reservations::Resource" do
    sequence(:name) { |n| "Resource #{n}" }
    sequence(:abbrv) { |n| "Res#{n}" }
    community { Defaults.community }

    trait :inactive do
      deactivated_at { Time.current - 1 }
    end

    trait :with_guidelines do
      guidelines { "Guideline 1" }

      after(:build) do |resource|
        resource.shared_guidelines.build(community: resource.community, name: "Foo", body: "Guideline 2")
        resource.shared_guidelines.build(community: resource.community, name: "Bar", body: "Guideline 3")
      end
    end
  end
end
