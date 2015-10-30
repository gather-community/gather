class CreateAccountsForExistingHouseholds < ActiveRecord::Migration
  def change
    Household.all.each do |h|
      h.create_account!
    end
  end
end
