FactoryBot.define do
  factory :resource, class: "Reservations::Resource" do
    sequence(:name) { |n| "Resource #{n}" }
    sequence(:abbrv) { |n| "Res#{n}" }
    community { default_community }

    trait :inactive do
      deactivated_at { Time.current - 1 }
    end
  end
end
