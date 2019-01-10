# frozen_string_literal: true

module Work
  # Models a template for a job reminder.
  # Doesn't support absolute times since that wouldn't make sense.
  class ReminderTemplate < ApplicationRecord
    belongs_to :job_template, class_name: "Work::JobTemplate", inverse_of: :reminder_templates
  end
end
