class ReservationRuleSetSerializer < ApplicationSerializer
  attributes :fixed_start_time, :fixed_end_time, :access_level

  def fixed_start_time
    object.fixed_start_time && I18n.l(object.fixed_start_time, format: :machine_readable)
  end

  def fixed_end_time
    object.fixed_end_time && I18n.l(object.fixed_end_time, format: :machine_readable)
  end
end
