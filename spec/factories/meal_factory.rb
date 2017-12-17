FactoryBot.define do
  factory :meal do
    transient do
      communities []
      no_resources false
    end

    served_at { Time.current + 7.days }
    capacity 64
    community { default_community }

    association :formula, factory: :meal_formula
    association :head_cook, factory: :user
    association :creator, factory: :user

    after(:build) do |meal, evaluator|
      meal.communities += evaluator.communities.presence || [meal.community]
      meal.resources = [create(:resource)] if meal.resources.empty? && !evaluator.no_resources
    end

    trait :with_asst do
      after(:build) do |meal|
        meal.asst_cooks << create(:user)
      end
    end

    trait :with_menu do
      title "Yummy food"
      entrees "Good stuff"
      allergen_gluten true
    end

    trait :finalized do
      with_menu
      status "finalized"

      after(:build) do |meal|
        meal.cost = build(:meal_cost)
      end
    end

    trait :cancelled do
      with_menu
      status "cancelled"
    end
  end
end
