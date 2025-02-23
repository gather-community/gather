# frozen_string_literal: true

class PopulateFormulaParts < ActiveRecord::Migration[5.1]
  TYPES = %i[adult_meat adult_veg senior_meat senior_veg teen_meat teen_veg
             big_kid_meat big_kid_veg little_kid_meat little_kid_veg].freeze
  PORTION_SIZES = {
    adult_meat: 1,
    adult_veg: 1,
    senior_meat: 0.75,
    senior_veg: 0.75,
    teen_meat: 0.75,
    teen_veg: 0.75,
    big_kid_meat: 0.5,
    big_kid_veg: 0.5,
    little_kid_meat: 0.25,
    little_kid_veg: 0.25
  }.freeze

  def up
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        Community.all.each do |community|
          type_map = TYPES.index_with { |t| meal_type_for_type(t, community) }
          community.meal_formulas.each do |formula|
            TYPES.each_with_index do |type_name, rank|
              next if (share = formula[type_name]).blank?

              share_formatted = formula.fixed_meal? ? share : share * 100
              Meals::FormulaPart.create!(formula: formula, type: type_map[type_name],
                                         share_formatted: share_formatted,
                                         portion_size: PORTION_SIZES[type_name],
                                         rank: rank)
            end
          end
        end
      end
    end
  end

  def down
    ActsAsTenant.without_tenant do
      Meals::FormulaPart.delete_all
      Meals::Type.delete_all
    end
  end

  private

  def meal_type_for_type(type, community)
    Meals::Type.create!(
      community: community,
      discounted: type.match?(/adult/),
      name: type.to_s.split("_").map(&:capitalize).join(" "),
      subtype: type.to_s.split("_")[-1].capitalize
    )
  end
end
