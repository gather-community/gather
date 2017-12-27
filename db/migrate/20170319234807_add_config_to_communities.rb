class AddConfigToCommunities < ActiveRecord::Migration[4.2]
  def change
    add_column :communities, :config, :jsonb
  end
end
