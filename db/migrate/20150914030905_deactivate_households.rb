class DeactivateHouseholds < ActiveRecord::Migration[4.2]
  def up
    Household.includes(:users).all.each do |h|
      h.user_deactivated
    end
  end
end
