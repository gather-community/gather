# frozen_string_literal: true

class PopulateFormulaParts < ActiveRecord::Migration[5.1]
  TYPES = %i[adult_meat adult_veg big_kid_meat big_kid_veg little_kid_meat little_kid_veg
             senior_meat senior_veg teen_meat teen_veg].freeze

  def up
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        Community.all.each do |community|
          type_map = TYPES.map { |t| [t, meal_type_for_type(t, community)] }.to_h
          community.meal_formulas.each do |formula|
            TYPES.each_with_index do |type_name, rank|
              next if (share = formula[type_name]).blank?
              Meals::FormulaPart.create!(formula: formula, type: type_map[type_name],
                                         share: share, rank: rank)
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
