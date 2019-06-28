# frozen_string_literal: true

FactoryBot.define do
  factory :meal, class: "Meals::Meal" do
    transient do
      communities { [] }
      no_resources { false }
      head_cook { nil }
      asst_cooks { [] }
      cleaners { [] }
    end

    served_at { Time.current + 7.days }
    capacity { 64 }
    community { Defaults.community }

    association :formula, factory: :meal_formula
    association :creator, factory: :user

    after(:build) do |meal, evaluator|
      meal.communities += evaluator.communities.presence || [meal.community]

      head_cook = evaluator.head_cook || create(:user, community: meal.community)
      build_assignment(meal, "Head Cook", head_cook)
      evaluator.asst_cooks.each { |user| build_assignment(meal, "Assistant Cook", user) }
      evaluator.cleaners.each { |user| build_assignment(meal, "Cleaner", user) }

      if meal.resources.empty? && !evaluator.no_resources
        meal.resources = [create(:resource, meal_hostable: true)]
      end
    end

    trait :with_menu do
      title { "Yummy food" }
      entrees { "Good stuff" }
      allergens { %w[Dairy Soy] }
    end

    trait :finalized do
      with_menu
      status { "finalized" }

      after(:build) do |meal|
        meal.cost = build(:meal_cost)
      end
    end

    trait :cancelled do
      with_menu
      status { "cancelled" }
    end
  end
end

def build_assignment(meal, role_title, user)
  role = meal.formula.roles.detect { |r| r.title == role_title } ||
    create(:meal_role, community: meal.community)
  meal.assignments.build(role: role, user: user)
end
