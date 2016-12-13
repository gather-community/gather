class RemoveGuardianIdFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :guardian_id, :integer
  end
end
