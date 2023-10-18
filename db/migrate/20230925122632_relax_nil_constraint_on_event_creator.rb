# frozen_string_literal: true

class RelaxNilConstraintOnEventCreator < ActiveRecord::Migration[7.0]
  def change
    change_column_null :calendar_events, :creator_temp_id, true
  end
end
