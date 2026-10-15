# frozen_string_literal: true

# Labels naming things the user owns now use "My" ("My Jobs") rather than "Your".
# Admins can rename system calendars, so only rows still carrying the old default name are changed.
class RenameYourSystemCalendarsToMy < ActiveRecord::Migration[8.1]
  RENAMES = {
    "Calendars::System::YourMealsCalendar" => ["Your Meals", "My Meals"],
    "Calendars::System::YourJobsCalendar" => ["Your Jobs", "My Jobs"]
  }.freeze

  def up
    RENAMES.each { |type, (old_name, new_name)| rename(type, old_name, new_name) }
  end

  def down
    RENAMES.each { |type, (old_name, new_name)| rename(type, new_name, old_name) }
  end

  private

  def rename(type, from, to)
    execute(<<~SQL.squish)
      UPDATE calendar_nodes SET name = #{quote(to)}, updated_at = NOW()
      WHERE type = #{quote(type)} AND name = #{quote(from)}
    SQL
  end

  def quote(value)
    connection.quote(value)
  end
end
