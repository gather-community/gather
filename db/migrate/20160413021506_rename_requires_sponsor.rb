class RenameRequiresSponsor < ActiveRecord::Migration
  def change
    rename_column :reservation_protocols, :requires_sponsor, :other_communities
  end
end
