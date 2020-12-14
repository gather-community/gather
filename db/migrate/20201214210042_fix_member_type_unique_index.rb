# frozen_string_literal: true

class FixMemberTypeUniqueIndex < ActiveRecord::Migration[6.0]
  def change
    remove_index :people_member_types, :name
    add_index :people_member_types, %i[community_id name], unique: true
  end
end
