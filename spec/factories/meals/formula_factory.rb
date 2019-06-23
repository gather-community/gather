# frozen_string_literal: true

FactoryBot.define do
  factory :meal_formula, class: "Meals::Formula" do
    transient do
      asst_cook_role { nil }
    end

    sequence(:name) { |n| "Formula #{n}" }
    community { Defaults.community }
    senior_meat { 0.75 }
    senior_veg { 0.6 }
    adult_meat { 1.0 }
    adult_veg { 0.9 }
    teen_meat { 1.0 }
    teen_veg { 0.9 }
    big_kid_meat { 0.75 }
    big_kid_veg { 0.6 }
    little_kid_meat { 0 }
    little_kid_veg { 0 }
    pantry_fee { 0.10 }
    meal_calc_type { "share" }
    pantry_calc_type { "percent" }
    roles do
      head_cook_role = Meals::Role.find_by(community_id: community.id, special: "head_cook") ||
        create(:meal_role, :head_cook, community: community)
      [head_cook_role, asst_cook_role].compact
    end

    after(:build) do |formula|
      rank = 0
      Signup::SIGNUP_TYPES.each do |st|
        next unless (share = formula.send(st))
        type = Meals::Type.new(community: formula.community,
                               discounted: share < 1,
                               name: st.split("_").map(&:capitalize).join(" "),
                               subtype: st.split("_")[-1].capitalize)
        formula.parts.build(rank: rank, share: share, type: type)
        rank += 1
      end
    end

    trait :with_asst_cook_role do
      asst_cook_role { create(:meal_role, title: "Assistant Cook", community: community) }
    end
  end
end
