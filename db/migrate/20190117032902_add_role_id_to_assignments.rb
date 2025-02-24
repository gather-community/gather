# frozen_string_literal: true

# At the point this migration is run, the assignments table won't have been renamed yet.
class Assignment < ApplicationRecord
  belongs_to :meal
end

class AddRoleIdToAssignments < ActiveRecord::Migration[5.1]
  KEYS_TO_TITLES = {head_cook: "Head Cook", asst_cook: "Assistant Cook",
                    cleaner: "Cleaner", table_setter: "Table Setter"}.freeze

  def up
    add_reference :assignments, :role, index: true, foreign_key: {to_table: :meal_roles}

    ActsAsTenant.without_tenant do
      Assignment.all.each do |assignment|
        community_id = assignment.meal.community_id
        role = Meals::Role.find_by(community_id: community_id,
                                   title: KEYS_TO_TITLES[assignment.role.to_sym])
        raise "Couldn't find role for cmty #{community_id}, role key #{assignment.role}" unless role

        assignment.update_column(:role_id, role.id)
      end
    end

    change_column_null :assignments, :role_id, false
  end
end
