# frozen_string_literal: true

class CreateGroupAffiliations < ActiveRecord::Migration[6.0]
  def up
    create_table :group_affiliations do |t|
      t.references :cluster, foreign_key: true, index: true, null: false
      t.references :group, foreign_key: true, index: true, null: false
      t.references :community, foreign_key: true, index: true, null: false
      t.index %i[community_id group_id], unique: true
    end
    execute("INSERT INTO group_affiliations(cluster_id, group_id, community_id)
      SELECT cluster_id, id, community_id FROM groups")
  end

  def down
    drop_table :group_affiliations
  end
end
