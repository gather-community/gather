# frozen_string_literal: true

# No reminders for meal jobs. For rest, set to rel_time of one day before.
class AddWorkReminderDefaults < ActiveRecord::Migration[5.1]
  def up
    execute("INSERT INTO work_reminders (cluster_id, job_id, rel_time, created_at, updated_at)
      SELECT cluster_id, id, 1440, NOW(), NOW() FROM work_jobs WHERE title NOT IN
        ('Head Cook', 'Assistant Cook', 'Meal Cleaner', 'Pizza Organizer', 'Pizza Cleaner')")
  end
end
