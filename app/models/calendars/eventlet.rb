# frozen_string_literal: true

class Calendars
  class Eventlet < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :event, class_name: "Calendars::Event", inverse_of: :eventlets
    belongs_to :calendar, class_name: "Calendars::Calendar", inverse_of: :eventlets
  end
end