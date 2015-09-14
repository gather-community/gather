class DeactivateHouseholds < ActiveRecord::Migration
  def up
    Household.includes(:users).all.each do |h|
      h.user_deactivated
    end
  end
end
