class AddCreditLimitToAccounts < ActiveRecord::Migration
  def up
    add_column :accounts, :credit_limit, :decimal, precision: 10, scale: 2
    CreditLimit.all.each do |cl|
      if Household.find_by(id: cl.household_id)
        account = Account.find_or_create_by!(community_id: cl.community_id, household_id: cl.household_id)
        account.update_attribute(:credit_limit, cl.amount)
      end
    end
  end

  def down
  end
end
