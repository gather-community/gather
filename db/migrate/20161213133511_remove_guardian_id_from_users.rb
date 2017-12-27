class RemoveGuardianIdFromUsers < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :guardian_id, :integer
  end
end
