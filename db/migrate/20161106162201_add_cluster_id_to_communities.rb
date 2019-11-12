# frozen_string_literal: true

class AddClusterIdToCommunities < ActiveRecord::Migration[4.2]
  def change
    add_reference :communities, :cluster, index: true, foreign_key: true
  end
end
