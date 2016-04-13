class ChangeProtocolOtherCommunitiesToString < ActiveRecord::Migration
  def up
    change_column :reservation_protocols, :other_communities, :string
  end
end
