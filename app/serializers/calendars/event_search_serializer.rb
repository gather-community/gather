# frozen_string_literal: true

module Calendars
  # Serializes Events for Elasticsearch.
  class EventSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :calendar_id, :name, :note, :location, :starts_at

    def kind = "event"
    def community_id = object.calendar.community_id
    def name = object.name.to_s
    def note = object.note.to_s
  end
end
