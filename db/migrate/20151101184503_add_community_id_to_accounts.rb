class AddCommunityIdToAccounts < ActiveRecord::Migration
  def change
    add_reference :accounts, :community, index: true, foreign_key: true
  end
end
