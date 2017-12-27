class ChangeProtocolOtherCommunitiesToString < ActiveRecord::Migration[4.2]
  def up
    change_column :reservation_protocols, :other_communities, :string
  end
end
