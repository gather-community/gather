# frozen_string_literal: true

FactoryBot.define do
  factory :meal_signup, class: "Meals::Signup" do
    transient do
      # Type-agnostic way of requesting a specific number of diners be included in the signup
      diner_count { nil }

      # Array of integers defining multiple diner counts.
      diner_counts { nil }
    end

    household
    meal

    after(:build) do |signup, evaluator|
      signup.adult_meat = evaluator.diner_count if evaluator.diner_count
      meal = signup.meal

      if evaluator.diner_counts.nil?
        # 73 TODO: Remove
        Meals::Signup::SIGNUP_TYPES.each do |st|
          next unless (count = signup.send(st)) && count > 0
          type = Meals::Type.new(community: meal.community,
                                 name: st.split("_").map(&:capitalize).join(" "),
                                 category: st.split("_")[-1].capitalize)
          signup.parts.build(count: count, type: type)
        end
      else
        # Create types and parts for the given share values.
        evaluator.diner_counts.each_with_index do |count, index|
          type = Meals::Type.new(community: meal.community,
                                 name: "Type #{rand(10_000_000..99_999_999)}")
          signup.parts.build(count: count, type: type)

          # 73 TODO: Remove
          # Need this to keep things in sync and avoid old validation errors.
          signup[Meals::Signup::SIGNUP_TYPES[index]] = count
        end
      end
    end

    trait :with_nums do
      adult_meat { 2 }
      little_kid_veg { 1 }
    end
  end
end
