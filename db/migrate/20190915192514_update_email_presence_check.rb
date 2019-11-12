# frozen_string_literal: true

class UpdateEmailPresenceCheck < ActiveRecord::Migration[5.1]
  def up
    remove_check_constraint(:users, :users_email_presence)
    add_check_constraint(:users, :email_presence,
                         "(
        child = true OR deactivated_at IS NOT NULL OR
        ((email IS NOT NULL) AND ((email)::text !~ '^\\s*$'::text))
      )")
  end

  def down
    remove_check_constraint(:users, :email_presence)
    add_check_constraint(:users, :users_email_presence,
                         "((NOT (child = false)) OR ((email IS NOT NULL) AND ((email)::text !~ '^\\s*$'::text)))")
  end
end
