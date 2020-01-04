# frozen_string_literal: true

class ChangeMembershipKindDefault < ActiveRecord::Migration[6.0]
  def change
    change_column_default(:group_memberships, :kind, "joiner")
  end
end
