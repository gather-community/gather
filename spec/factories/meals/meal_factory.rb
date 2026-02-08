# frozen_string_literal: true

# == Schema Information
#
# Table name: meals
#
#  id              :integer          not null, primary key
#  allergens       :jsonb            not null
#  auto_close_time :datetime
#  capacity        :integer          not null
#  cluster_id      :integer          not null
#  community_id    :integer          not null
#  created_at      :datetime         not null
#  creator_id      :integer          not null
#  dessert         :text
#  entrees         :text
#  formula_id      :integer          not null
#  kids            :text
#  menu_posted_at  :datetime
#  no_allergens    :boolean          default(FALSE), not null
#  notes           :text
#  served_at       :datetime         not null
#  side            :text
#  status          :string           default("open"), not null
#  title           :string
#  updated_at      :datetime         not null
#
FactoryBot.define do
  factory :meal, class: "Meals::Meal" do
    transient do
      communities { [] }
      no_calendars { false }
      head_cook { nil }
      head_cook_role_title { nil }
      asst_cooks { [] }
      cleaners { [] }
    end

    served_at { Time.current + 7.days }
    capacity { 64 }
    community { Defaults.community }
    source_form { "main" }

    association :formula, factory: :meal_formula
    association :creator, factory: :user

    after(:build) do |meal, evaluator|
      meal.communities += evaluator.communities.presence || [meal.community]

      unless evaluator.head_cook == false
        head_cook = evaluator.head_cook || create(:user, community: meal.community)
        build_assignment(meal, evaluator.head_cook_role_title || "Head Cook", head_cook)
      end
      evaluator.asst_cooks.each { |user| build_assignment(meal, "Assistant Cook", user) }
      evaluator.cleaners.each { |user| build_assignment(meal, "Cleaner", user) }

      if meal.calendars.empty? && !evaluator.no_calendars
        meal.calendars = [create(:calendar, meal_hostable: true)]
      end
    end

    trait :with_menu do
      title { "Yummy food" }
      entrees { "Good stuff" }
      allergens { %w[Dairy Soy] }
    end

    trait :open do
      status { "open" }
    end

    trait :closed do
      status { "closed" }
    end

    trait :finalized do
      with_menu
      status { "finalized" }

      after(:build) do |meal|
        meal.cost = build(:meal_cost, :with_parts)
        meal.transactions << create(:meal_transaction,
          incurred_on: meal.served_at.to_date + 2.days, statementable: meal)
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
