class AddJobChoosingProxyIdToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :job_choosing_proxy_id, :integer, index: true
    add_foreign_key :users, :users, column: :job_choosing_proxy_id
  end
end
