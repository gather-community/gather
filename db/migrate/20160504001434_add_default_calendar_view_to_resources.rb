class AddDefaultCalendarViewToResources < ActiveRecord::Migration
  def change
    add_column :resources, :default_calendar_view, :string, null: false, default: 'week'
  end
end
