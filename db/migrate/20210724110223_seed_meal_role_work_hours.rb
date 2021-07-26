# frozen_string_literal: true

class SeedMealRoleWorkHours < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      Meals::Role.where(time_type: "date_time").find_each do |role|
        role.update_column(:work_hours, (role.shift_end - role.shift_start).to_f / 60)
      end
    end
  end
end
