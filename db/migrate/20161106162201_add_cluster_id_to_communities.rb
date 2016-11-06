class AddClusterIdToCommunities < ActiveRecord::Migration
  def change
    add_reference :communities, :cluster, index: true, foreign_key: true
  end
end
