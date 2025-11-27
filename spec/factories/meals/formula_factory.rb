# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_formulas
#
#  id                   :integer          not null, primary key
#  cluster_id           :integer          not null
#  community_id         :integer          not null
#  created_at           :datetime         not null
#  deactivated_at       :datetime
#  is_default           :boolean          default(FALSE), not null
#  meal_calc_type       :string           not null
#  name                 :string           not null
#  pantry_calc_type     :string           not null
#  pantry_fee           :decimal(10, 4)   not null
#  pantry_reimbursement :boolean          default(FALSE)
#  takeout              :boolean          default(TRUE), not null
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :meal_formula, class: "Meals::Formula" do
    transient do
      head_cook_role do
        Meals::Role.find_by(community_id: community.id, special: "head_cook") ||
          create(:meal_role, :head_cook, community: community)
      end
      parts_attrs { [{type: "Adult", share: "100%"}, {type: "Teen", share: "75%"}] }
    end

    sequence(:name) { |n| "Formula #{n}" }
    community { Defaults.community }
    meal_calc_type { "share" }
    pantry_calc_type { "percent" }
    pantry_fee { 0.10 }
    roles { [head_cook_role] }

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

    trait :head_cook_only do
      roles { [head_cook_role] }
    end

    trait :with_two_roles do
      roles do
        [
          head_cook_role,
          create(:meal_role, title: "Assistant Cook", community: community),
        ]
      end
    end

    trait :with_three_roles do
      roles do
        [
          head_cook_role,
          create(:meal_role, title: "Assistant Cook", community: community),
          create(:meal_role, title: "Cleaner", community: community)
        ]
      end
    end

    trait :inactive do
      deactivated_at { Time.current - 1 }
    end
  end
end
