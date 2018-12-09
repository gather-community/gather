# frozen_string_literal: true

class AddEmailNullConstraint < ActiveRecord::Migration[5.1]
  def change
    add_presence_constraint(:users, :email, if: "child = 'f'")
  end
end
