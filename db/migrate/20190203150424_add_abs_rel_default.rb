# frozen_string_literal: true

class AddAbsRelDefault < ActiveRecord::Migration[5.1]
  def change
    change_column_default :reminders, :abs_rel, "relative"
  end
end
