# frozen_string_literal: true

class AddChildNotConfirmedConstraint < ActiveRecord::Migration[5.1]
  def change
    execute("UPDATE users SET confirmed_at = NULL WHERE child = 't'")
    add_check_constraint :users, "child = 'f' OR confirmed_at IS NULL"
  end
end
