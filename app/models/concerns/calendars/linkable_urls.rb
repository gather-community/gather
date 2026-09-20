# frozen_string_literal: true

module Calendars
  # Turns an eventlet's linkable into a URL. Shared by the JSON serializer (which the calendar grid
  # reads) and the ICS generator, so the two can't drift apart.
  module LinkableUrls
    extend ActiveSupport::Concern

    included do
      include Rails.application.routes.url_helpers
    end

    private

    def linkable_path(linkable, **options)
      if linkable.is_a?(Work::Shift)
        # Work shift show pages are period-scoped, so they can't be reached polymorphically.
        work_period_shift_path(linkable.period, linkable, **options)
      else
        polymorphic_path(linkable, **options)
      end
    end

    def linkable_url(linkable, **options)
      if linkable.is_a?(Work::Shift)
        work_period_shift_url(linkable.period, linkable, **options)
      else
        polymorphic_url(linkable, **options)
      end
    end
  end
end
