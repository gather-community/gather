# frozen_string_literal: true

class ChangeJobTemplatesToMealRoles < ActiveRecord::Migration[5.1]
  def change
    rename_table :work_job_templates, :meal_roles
    remove_column :meal_roles, :hours, :integer
    remove_column :meal_roles, :meal_related, :boolean
    remove_column :meal_roles, :requester_id, :integer
    add_column :meal_roles, :count_per_meal, :integer, null: false, default: 1
    add_column :meal_roles, :deactivated_at, :datetime
    remove_index :meal_roles, %i[community_id title]
    add_index :meal_roles, %i[cluster_id community_id title], where: "(deactivated_at IS NULL)"

    rename_table :work_reminder_templates, :meal_role_reminders
    rename_column :meal_role_reminders, :job_template_id, :meal_role_id
  end
end
