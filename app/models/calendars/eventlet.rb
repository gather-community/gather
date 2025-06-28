# frozen_string_literal: true

module Calendars
  class Eventlet < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :event, class_name: "Calendars::Event", inverse_of: :eventlets
    belongs_to :calendar, class_name: "Calendars::Calendar", inverse_of: :eventlets

    scope :between, ->(range) { where("starts_at < ? AND ends_at > ?", range.last, range.first) }
  end
end