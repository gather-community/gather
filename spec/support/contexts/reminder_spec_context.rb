# frozen_string_literal: true

shared_context "reminders" do
  def create_reminder(factory, time_or_magnitude, unit_sign, **attribs)
    absolute = !time_or_magnitude.is_a?(Numeric)
    create(factory, attribs.merge(
      abs_rel: absolute ? "absolute" : "relative",
      abs_time: absolute ? time_or_magnitude : nil,
      rel_magnitude: absolute ? nil : time_or_magnitude,
      rel_unit_sign: unit_sign
    ))
  end

  def create_work_job_reminder(job, time_or_magnitude, unit_sign = nil, **attribs)
    create_reminder(:work_job_reminder, time_or_magnitude, unit_sign, **attribs, job: job)
  end

  def create_meal_role_reminder(role, time_or_magnitude, unit_sign = nil, **attribs)
    create_reminder(:meal_role_reminder, time_or_magnitude, unit_sign, **attribs, role: role)
  end
end
