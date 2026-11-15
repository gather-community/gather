# frozen_string_literal: true

module Calendars
  # Serializes Calendars for Elasticsearch.
  class CalendarSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :name, :guidelines

    def kind = "calendar"

    def guidelines = object.guidelines.to_s
  end
end
