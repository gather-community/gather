# frozen_string_literal: true

# Base class for all reminder jobs
class ReminderJob < ApplicationJob
  protected

  def each_community_at_correct_hour
    each_community do |community|
      yield(community) if correct_hour?
    end
  end

  def correct_hour?
    Rails.env.development? || Time.current.hour == Settings.reminders.time_of_day
  end
end
