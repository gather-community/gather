# frozen_string_literal: true

class ReminderDecorator < ApplicationDecorator
  delegate_all

  def rel_magnitude_to_i_or_f
    return nil if rel_magnitude.blank?

    to_int_if_no_fractional_part(rel_magnitude)
  end

  def to_s
    h.safe_join([time, note_tag].compact, ": ")
  end

  private

  def time
    if abs_time?
      t("work/job_reminder.absolute", time: l(abs_time))
    else
      t("work/job_reminder.relative.#{rel_unit_sign}", count: to_int_if_no_fractional_part(rel_magnitude))
    end
  end

  def note_tag
    note.present? ? h.tag.strong(note) : nil
  end
end
