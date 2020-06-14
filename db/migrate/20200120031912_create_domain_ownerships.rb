# frozen_string_literal: true

class CreateDomainOwnerships < ActiveRecord::Migration[6.0]
  def change
    create_table :domain_ownerships do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :community, null: false, foreign_key: true
      t.references :domain, null: false, foreign_key: true
      t.index %i[cluster_id community_id domain_id], unique: true, name: :index_domain_ownerships_unique
      t.timestamps
    end
  end
end
