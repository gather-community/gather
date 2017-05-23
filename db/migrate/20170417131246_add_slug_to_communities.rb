class AddSlugToCommunities < ActiveRecord::Migration
  def up
    add_column :communities, :slug, :string, unique: true
    ActsAsTenant.without_tenant do
      Community.all.each { |c| c.update_column(:slug, c.name.downcase.gsub(" ", "")) }
    end
    change_column_null :communities, :slug, false
  end
end
