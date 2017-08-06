class AddIsDefaultToMealFormulas < ActiveRecord::Migration
  def up
    add_column :meal_formulas, :is_default, :boolean, default: false, null: false
    ActsAsTenant.without_tenant do
      # Since there used to be only one formula allowed at a time,
      # set all formulas to deactivated except the latest one for each community.
      # Also set that one to default.
      execute("UPDATE meal_formulas SET deactivated_at = NOW()")
      Community.all.pluck(:id).each do |id|
        latest = Meals::Formula.where(community_id: id).order(created_at: :desc).first
        latest.update_attributes(is_default: true, deactivated_at: nil)
      end
    end
  end

  def down
    remove_column :meal_formulas, :is_default
  end
end
