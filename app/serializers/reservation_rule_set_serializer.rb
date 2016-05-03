class ReservationRuleSetSerializer < ActiveModel::Serializer
  attributes :fixed_start_time, :fixed_end_time, :access_level

  def fixed_start_time
    object.fixed_start_time.try(:to_s, :machine_datetime_no_zone)
  end

  def fixed_end_time
    object.fixed_end_time.try(:to_s, :machine_datetime_no_zone)
  end
end
