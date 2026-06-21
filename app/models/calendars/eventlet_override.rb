# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_eventlet_overrides
#
#  id                :bigint           not null, primary key
#  cluster_id        :bigint           not null
#  event_override_id :bigint           not null
#  eventlet_id       :bigint           not null
#  deleted           :boolean          not null, default: false
#  start_offset      :integer
#  end_offset        :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
module Calendars
  class EventletOverride < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :event_override, class_name: "Calendars::EventOverride",
      inverse_of: :eventlet_overrides
    belongs_to :eventlet, class_name: "Calendars::Eventlet",
      inverse_of: :eventlet_overrides

    validates :start_offset, inclusion: {in: -Eventlet::MAX_OFFSET_SECONDS..Eventlet::MAX_OFFSET_SECONDS},
      allow_nil: true
    validates :end_offset, inclusion: {in: -Eventlet::MAX_OFFSET_SECONDS..Eventlet::MAX_OFFSET_SECONDS},
      allow_nil: true
    validate :eventlet_matches_event
    validate :override_has_purpose

    def occurrence_start
      event_override.occurrence_start
    end

    private

    def eventlet_matches_event
      return unless event_override && eventlet
      return if eventlet.event_id == event_override.event_id
      errors.add(:eventlet, "must belong to the same event as the override")
    end

    def override_has_purpose
      return if deleted?
      return if !start_offset.nil? || !end_offset.nil?
      errors.add(:base, "must either delete the occurrence or provide offset changes")
    end
  end
end
