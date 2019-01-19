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
    association :creator, factory: :user

    after(:build) do |meal|
      return if meal.head_cook_assign.present?
      meal.build_head_cook_assign(old_role: "head_cook", user: create(:user),
                                  role: meal.formula.roles.detect { |r| r.special == "head_cook" })
    end

    after(:build) do |meal, evaluator|
      meal.communities += evaluator.communities.presence || [meal.community]
      if meal.resources.empty? && !evaluator.no_resources
        meal.resources = [create(:resource, meal_hostable: true)]
      end
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
