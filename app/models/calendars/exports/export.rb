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

      delegate :community, to: :user
      delegate :calendar_token, to: :community, prefix: true

      def initialize(user: nil, community: nil)
        raise ArgumentError, "One of user or community required" if user.nil? && community.nil?

        # Make a temporary stand-in user if no user given.
        self.user = user || User.new(household: Household.new(community: community))
      end

      def calendar_name
        I18n.t("calendars.#{i18n_key}", community: Community.multiple? ? user.community_name : "").strip
      end

      def generate
        self.events = events_for_objects(objects)
        IcalGenerator.new(self).generate
      end

      protected

      def events_for_objects(objects)
        objects.map do |object|
          Event.new(basic_event_attribs(object))
        end
      end

      def basic_event_attribs(object)
        {
          obj_id: object.id,
          starts_at: starts_at(object),
          ends_at: ends_at(object),
          location: location(object),
          summary: summary(object),
          description: description(object),
          url: url(object),
          kind_name: kind_name(object)
        }
      end

      def url_for(obj, url_helper_method)
        host = "#{user.subdomain}.#{Settings.url.host}"
        Rails.application.routes.url_helpers.send(url_helper_method, obj,
                                                  Settings.url.to_h.slice(:port, :protocol).merge(host: host))
      end

      def starts_at(object)
        object.starts_at
      end

      def ends_at(object)
        object.ends_at
      end

      def description(_object)
        nil
      end

      def location(object)
        object.location_name
      end

      def objects
        @objects ||= scope.decorate.to_a
      end

      private

      def i18n_key
        self.class.name.match(/Calendars::Exports::(.+)Export/)[1].underscore
      end
    end
  end
end
