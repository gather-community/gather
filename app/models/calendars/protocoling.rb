# frozen_string_literal: true

module Calendars
  # Join class for Calendar and Calendars::Protocol
  class Protocoling < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :protocol, class_name: "Calendars::Protocol"
    belongs_to :calendar, class_name: "Calendars::Calendar"
  end
end
