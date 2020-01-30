# frozen_string_literal: true

class AddGroupReferenceToMailmanList < ActiveRecord::Migration[6.0]
  def change
    add_reference :group_mailman_lists, :group, index: true, foreign_key: true, null: false
  end
end
