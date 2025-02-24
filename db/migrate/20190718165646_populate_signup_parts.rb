# frozen_string_literal: true

class PopulateSignupParts < ActiveRecord::Migration[5.1]
  TYPES = %i[adult_meat adult_veg senior_meat senior_veg teen_meat teen_veg
             big_kid_meat big_kid_veg little_kid_meat little_kid_veg].freeze

  def up
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        Community.all.each do |community|
          type_map = TYPES.index_with { |t| meal_type_for_type(t, community) }
          Meals::Signup.where(meal_id: community.meals.pluck(:id)).find_each do |signup|
            TYPES.each do |type_name|
              next if (count = signup.send(type_name)).zero?

              Meals::SignupPart.create!(signup: signup, type: type_map[type_name], count: count)
            end
          end
        end
      end
    end
  end

  def down
    ActsAsTenant.without_tenant do
      Meals::SignupPart.delete_all
    end
  end

  private

  def meal_type_for_type(type, community)
    Meals::Type.find_by(community: community, name: type.to_s.split("_").map(&:capitalize).join(" ")) ||
      (raise "Couldn't find type #{type} for community #{community.id}")
  end
end
