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

    # The ±MAX_OFFSET_SECONDS offset bound is a data invariant enforced by a DB check constraint (see
    # the eventlet_override_start/end_offset_within_bounds constraints), the same as on Eventlet, so it
    # holds for every writer; EventletForm#offsets_within_range supplies the user-facing message.
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
