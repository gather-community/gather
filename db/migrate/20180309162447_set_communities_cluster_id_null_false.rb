class SetCommunitiesClusterIdNullFalse < ActiveRecord::Migration[5.1]
  def change
    change_column_null(:communities, :cluster_id, false)
  end
end
