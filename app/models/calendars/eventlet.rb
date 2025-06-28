# frozen_string_literal: true

module Calendars
  class Eventlet < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :event, class_name: "Calendars::Event", inverse_of: :eventlets
    belongs_to :calendar, class_name: "Calendars::Calendar", inverse_of: :eventlets

    delegate :kind, to: :event

    delegate :community_id, :color, to: :calendar
    delegate :name, to: :calendar, prefix: true
    delegate :access_level, :fixed_start_time?, :fixed_end_time?, :requires_kind?, to: :rule_set

    scope :between, ->(range) { where("starts_at < ? AND ends_at > ?", range.last, range.first) }

    # RuleSet needs to know `kind` to give a definitive answer on event permissions.
    # At event grid or event form load time, kind isn't known,
    # so some rules can't be applied until event submission.
    # But many protocols don't involve kind, and for those we can use the RuleSet to show things
    # about the RuleSet in the UI like the event form or the event grid.
    # In those cases, we can use a sample Event object with nil kind.
    def rule_set
      # Don't memoize this, it causes all kinds of bugs. Worth the performance hit.
      Rules::RuleSet.build_for(calendar: calendar, kind: kind)
    end
  end
end