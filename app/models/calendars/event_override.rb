# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_event_overrides
#
#  id               :bigint           not null, primary key
#  cluster_id       :bigint           not null
#  eventlet_id      :bigint           not null
#  occurrence_start :datetime         not null
#  deleted          :boolean          not null, default: false
#  starts_at        :datetime
#  ends_at          :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module Calendars
  class EventOverride < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :eventlet, class_name: "Calendars::Eventlet", inverse_of: :overrides

    validates :occurrence_start, presence: true
    validate :occurrence_must_be_in_series
    validate :time_range_valid
    validate :override_has_purpose

    private

    def occurrence_must_be_in_series
      return unless occurrence_start && eventlet&.event&.recurring?
      return if eventlet.event.schedule.occurs_at?(occurrence_start)
      errors.add(:occurrence_start, "is not a valid occurrence in this series")
    end

    def time_range_valid
      return unless starts_at && ends_at
      errors.add(:ends_at, "must be after start time") unless ends_at > starts_at
    end

    def override_has_purpose
      return if deleted?
      return if starts_at? && ends_at?
      errors.add(:base, "must either delete the occurrence or provide new start and end times")
    end
  end
end
