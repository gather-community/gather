# frozen_string_literal: true

class PopulateCostParts < ActiveRecord::Migration[5.1]
  TYPES = %i[adult_meat adult_veg senior_meat senior_veg teen_meat teen_veg
             big_kid_meat big_kid_veg little_kid_meat little_kid_veg].freeze

  def up
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        Community.all.each do |community|
          type_map = TYPES.index_with { |t| meal_type_for_type(t, community) }
          community.meals.each do |meal|
            next if meal.cost.nil?

            TYPES.each do |type_name|
              next if (value = meal.cost.send(type_name)).blank?

              Meals::CostPart.create!(cost: meal.cost, type: type_map[type_name], value: value)
            end
          end
        end
      end
    end
  end

  def down
    ActsAsTenant.without_tenant do
      Meals::CostPart.delete_all
    end
  end

  private

  def meal_type_for_type(type, community)
    Meals::Type.find_by(community: community, name: type.to_s.split("_").map(&:capitalize).join(" ")) ||
      (raise "Couldn't find type #{type} for community #{community.id}")
  end
end
