class AddMaxlengthForCommunityAndClusterNames < ActiveRecord::Migration[5.1]
  def up
    change_column :clusters, :name, :string, limit: 20
    change_column :communities, :name, :string, limit: 20
  end

  def down
    change_column :clusters, :name, :string, limit: nil
    change_column :communities, :name, :string, limit: nil
  end
end
