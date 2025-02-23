# frozen_string_literal: true

class ChangeChildToFullAccessInConstraints < ActiveRecord::Migration[6.0]
  def change
    remove_check_constraint(:users, "child = false OR confirmed_at IS NULL", name: :children_not_confirmed)
    remove_check_constraint(:users, "((child = true) OR (deactivated_at IS NOT NULL) OR " \
                                    "((email IS NOT NULL) AND ((email)::text !~ '^\\s*$'::text)))", name: :email_presence)
    add_check_constraint(:users, "full_access = true OR confirmed_at IS NULL",
                         name: :full_access_not_confirmed)
    add_check_constraint(:users, "((full_access = false) OR (deactivated_at IS NOT NULL) OR " \
                                 "((email IS NOT NULL) AND ((email)::text !~ '^\\s*$'::text)))", name: :email_presence)
  end
end
