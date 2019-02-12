# frozen_string_literal: true

module Work
  class ReminderDecorator < WorkDecorator
    delegate_all

    def to_s
      h.safe_join([time, note_tag].compact, ": ")
    end

    private

    def time
      if abs_time?
        t("work/job_reminder.absolute", time: I18n.l(abs_time))
      else
        t("work/job_reminder.relative.#{rel_unit_sign}", count: to_int_if_no_fractional_part(rel_magnitude))
      end
    end

    def note_tag
      note.present? ? h.content_tag(:strong, note) : nil
    end
  end
end
