# frozen_string_literal: true

# Labels naming things the user owns now use "My" ("My Jobs") rather than "Your", and so do the
# calendar classes. Renames the STI type of the two personal system calendars, and their names too.
# Admins can rename system calendars, so only rows still carrying the old default name get the new one.
class RenameYourSystemCalendarsToMy < ActiveRecord::Migration[8.1]
  RENAMES = [
    {old_type: "Calendars::System::YourMealsCalendar", new_type: "Calendars::System::MyMealsCalendar",
     old_name: "Your Meals", new_name: "My Meals"},
    {old_type: "Calendars::System::YourJobsCalendar", new_type: "Calendars::System::MyJobsCalendar",
     old_name: "Your Jobs", new_name: "My Jobs"}
  ].freeze

  def up
    RENAMES.each do |r|
      rename(type: r[:old_type], from: r[:old_name], to: r[:new_name])
      retype(from: r[:old_type], to: r[:new_type])
    end
  end

  def down
    RENAMES.each do |r|
      retype(from: r[:new_type], to: r[:old_type])
      rename(type: r[:old_type], from: r[:new_name], to: r[:old_name])
    end
  end

  private

  def rename(type:, from:, to:)
    execute(<<~SQL.squish)
      UPDATE calendar_nodes SET name = #{quote(to)}, updated_at = NOW()
      WHERE type = #{quote(type)} AND name = #{quote(from)}
    SQL
  end

  def retype(from:, to:)
    execute("UPDATE calendar_nodes SET type = #{quote(to)} WHERE type = #{quote(from)}")
  end

  def quote(value)
    connection.quote(value)
  end
end
