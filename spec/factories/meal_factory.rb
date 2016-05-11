FactoryGirl.define do
  factory :meal do
    transient do
      communiites []
    end

    served_at { Time.now + 7.days }
    capacity 64
    association :head_cook, factory: :user
    association :host_community, factory: :community
    association :creator, factory: :user

    after(:build) do |meal, evaluator|
      meal.communities += evaluator.communities.presence || [meal.host_community]
    end

    trait :with_menu do
      title "Yummy food"
      entrees "Good stuff"
      allergen_gluten true
    end
  end
end