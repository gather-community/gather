# frozen_string_literal: true

class AddCheckForEmailIfConfirmed < ActiveRecord::Migration[5.1]
  def change
    add_check_constraint(:users, :unconfirmed_if_no_email, "email IS NOT NULL OR confirmed_at IS NULL")
  end
end
