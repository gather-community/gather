# frozen_string_literal: true

FactoryBot.define do
  factory :meal_formula, class: "Meals::Formula" do
    transient do
      asst_cook_role { nil }
      parts_attrs { [{type: "Adult", share: "100%"}, {type: "Teen", share: "75%"}] }
    end

    sequence(:name) { |n| "Formula #{n}" }
    community { Defaults.community }
    meal_calc_type { "share" }
    pantry_calc_type { "percent" }
    pantry_fee { 0.10 }
    roles do
      head_cook_role = Meals::Role.find_by(community_id: community.id, special: "head_cook") ||
        create(:meal_role, :head_cook, community: community)
      [head_cook_role, asst_cook_role].compact
    end

    after(:build) do |formula, evaluator|
      # Create types and parts for the given share values.
      evaluator.parts_attrs.each_with_index do |attrs, index|
        attrs = {share: attrs} unless attrs.is_a?(Hash)
        type = Meals::Type.find_or_initialize_by(community: formula.community, category: attrs[:category],
                                                 name: attrs[:type] || "#{formula.name} Type #{index + 1}")
        formula.parts.build(rank: index, type: type, share_formatted: attrs[:share] || "100%",
                            portion_size: attrs[:portion] || 1)
      end
    end

    trait :with_asst_cook_role do
      asst_cook_role { create(:meal_role, title: "Assistant Cook", community: community) }
    end
  end
end
