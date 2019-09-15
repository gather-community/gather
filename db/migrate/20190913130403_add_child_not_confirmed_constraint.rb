# frozen_string_literal: true

class AddChildNotConfirmedConstraint < ActiveRecord::Migration[5.1]
  def up
    execute("UPDATE users SET confirmed_at = NULL WHERE child = 't'")
    add_check_constraint(:users, :children_not_confirmed, "child = 'f' OR confirmed_at IS NULL")
  end

  def down
    remove_check_constraint(:users, :children_not_confirmed)
  end
end
