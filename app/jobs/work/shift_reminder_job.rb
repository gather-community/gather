# frozen_string_literal: true

module Work
  # Sends notifications of job shifts.
  class ShiftReminderJob < ReminderJob
    def perform
      ActsAsTenant.without_tenant do
        reminder_shift_pairs.each do |community_id, pairs|
          with_community(Community.find(community_id)) do
            pairs.each { |pair| deliver_for_pair(pair) }
          end
        end
      end
    end

    private

    # Handles delivering reminders for a given reminder-shift pair.
    def deliver_for_pair(pair)
      reminder = Reminder.find(pair["reminder_id"])
      shift = Shift.find(pair["shift_id"])
      shift.assignments.each do |assign|
        WorkMailer.shift_reminder(assign, reminder).deliver_now
      end
      ReminderDelivery.create!(reminder: reminder, shift: shift)
    end

    # Gets ID pairs of reminders and shifts that are ready to be sent, grouped by community_id.
    # We need to use SQL here for scalability.
    # Returns a hash of form {community_id => [{reminder_id => x, shift_id => y}, ...], ...}
    def reminder_shift_pairs
      result = ApplicationRecord.connection.execute(sql)
      result.to_a.group_by { |row| row["community_id"] }
    end

    def sql
      "SELECT reminders.id AS reminder_id, shifts.id AS shift_id, periods.community_id
        FROM work_reminders reminders
          INNER JOIN work_jobs jobs ON reminders.job_id = jobs.id
          INNER JOIN work_shifts shifts ON shifts.job_id = jobs.id
          INNER JOIN work_periods periods ON jobs.period_id = periods.id
        WHERE
          CASE WHEN reminders.abs_time IS NOT NULL THEN reminders.abs_time <= #{sql_now}
            ELSE shifts.starts_at + (rel_time || ' MINUTES')::INTERVAL <= #{sql_now} END AND
          NOT EXISTS(SELECT id FROM work_reminder_deliveries deliveries
            WHERE deliveries.shift_id = shifts.id AND deliveries.reminder_id = reminders.id)"
    end

    def sql_now
      @sql_now ||= "'#{Time.current.utc.to_s(:machine_datetime_no_zone)}'::TIMESTAMP"
    end
  end
end
