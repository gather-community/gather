# frozen_string_literal: true

shared_context "work reminders" do
  def create_reminder(job, time_or_magnitude, unit_sign = nil, note: nil)
    absolute = !time_or_magnitude.is_a?(Numeric)
    create(:work_job_reminder,
      job: job,
      abs_rel: absolute ? "absolute" : "relative",
      abs_time: absolute ? time_or_magnitude : nil,
      rel_magnitude: absolute ? nil : time_or_magnitude,
      rel_unit_sign: unit_sign,
      note: note)
  end
end
