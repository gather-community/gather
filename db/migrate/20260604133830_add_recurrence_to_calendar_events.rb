class AddRecurrenceToCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :calendar_events, :recurrence_rule, :jsonb
    add_column :calendar_events, :recurrence_end_date, :date
    add_index :calendar_events, :recurrence_end_date
  end
end
