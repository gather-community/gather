class RenameRequiresSponsor < ActiveRecord::Migration[4.2]
  def change
    rename_column :reservation_protocols, :requires_sponsor, :other_communities
  end
end
