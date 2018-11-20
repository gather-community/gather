# frozen_string_literal: true

require "icalendar"
require "icalendar/tzinfo"

module Calendars
  module Exports
    # Abstract parent class.
    # Generates ICS files for various calendars in the system.
    # Takes only user. Responsible for loading objects and generating calendar data for them.
    class Export
      MAX_EVENT_AGE = 1.year

      attr_accessor :user, :events

      def initialize(user:)
        self.user = user
      end

      def calendar_name
        I18n.t("calendars.#{i18n_key}", community: Community.multiple? ? user.community_name : "").strip
      end

      # Returns a date from the first object in the list. Returns nil if no objects.
      def sample_time
        objects.first&.starts_at
      end

      def generate
        self.events = objects.map do |object|
          Event.new(
            object_id: object.id,
            starts_at: start_time(object),
            ends_at: end_time(object),
            location: location(object),
            summary: summary(object),
            description: description(object),
            url: url(object)
          )
        end
        IcalGenerator.new(self).generate
      end

      protected

      def url_for(obj, url_helper_method)
        host = "#{user.subdomain}.#{Settings.url.host}"
        Rails.application.routes.url_helpers.send(url_helper_method, obj,
          Settings.url.to_h.slice(:port, :protocol).merge(host: host))
      end

      def start_time(object)
        object.starts_at
      end

      def end_time(object)
        object.ends_at
      end

      def description(_object)
        nil
      end

      def location(object)
        object.location_name
      end

      private

      def objects
        @objects ||= scope.decorate.to_a
      end

      def i18n_key
        self.class.name.match(/Calendars::Exports::(.+)Export/)[1].underscore
      end
    end
  end
end
