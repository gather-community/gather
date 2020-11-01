# frozen_string_literal: true

class AddMemberTypeIdToHouseholds < ActiveRecord::Migration[6.0]
  def change
    add_reference :households, :member_type, foreign_key: {to_table: :people_member_types},
                                             index: true, null: true
  end
end
