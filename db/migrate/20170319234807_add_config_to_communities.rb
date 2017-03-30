class AddConfigToCommunities < ActiveRecord::Migration
  def change
    add_column :communities, :config, :jsonb
  end
end
