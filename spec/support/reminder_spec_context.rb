# frozen_string_literal: true

shared_context "reminders" do
  def create_reminder(job, time_or_magnitude, unit_sign = nil)
    create(:work_reminder,
      job: job,
      abs_rel: time_or_magnitude.is_a?(String) ? "absolute" : "relative",
      abs_time: time_or_magnitude.is_a?(String) ? time_or_magnitude : nil,
      rel_magnitude: time_or_magnitude.is_a?(String) ? nil : time_or_magnitude,
      rel_unit_sign: unit_sign)
  end
end
