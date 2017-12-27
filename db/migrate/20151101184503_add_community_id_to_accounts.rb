class AddCommunityIdToAccounts < ActiveRecord::Migration[4.2]
  def change
    add_reference :accounts, :community, index: true, foreign_key: true
  end
end
