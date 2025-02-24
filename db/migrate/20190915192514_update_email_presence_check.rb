# frozen_string_literal: true

class UpdateEmailPresenceCheck < ActiveRecord::Migration[5.1]
  def up
    remove_check_constraint(:users, :users_email_presence)
    add_check_constraint(:users,
                         "(
        child = true OR deactivated_at IS NOT NULL OR
        ((email IS NOT NULL) AND ((email)::text !~ '^\\s*$'::text))
      )", name: :email_presence)
  end

  def down
    remove_check_constraint(:users, :email_presence)
    add_check_constraint(:users,
                         "((NOT (child = false)) OR ((email IS NOT NULL) AND ((email)::text !~ '^\\s*$'::text)))", name: :users_email_presence)
  end
end
