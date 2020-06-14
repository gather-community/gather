# frozen_string_literal: true

class AddNullConstraintForUserFake < ActiveRecord::Migration[6.0]
  def change
    change_column_null(:users, :fake, false)
  end
end
