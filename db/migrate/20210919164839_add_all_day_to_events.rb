class AddAllDayToEvents < ActiveRecord::Migration[6.0]
  def change
    add_column :calendar_events, :all_day, :boolean, default: false, null: false
  end
end
