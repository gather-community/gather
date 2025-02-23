# frozen_string_literal: true

module Meals
  # Handles creation and updating of events associated with meals.
  class EventHandler
    include ActionView::Helpers::TextHelper

    attr_accessor :meal

    def initialize(meal)
      self.meal = meal
    end

    # Builds the event associated with the meal. Deletes any previous events.
    # Builds, not creates, because we want to see if validation passes first.
    def build_events
      current_events = []
      meal.resourcings.each do |resourcing|
        event = meal.events.detect { |r| r.calendar == resourcing.calendar }
        # Don't adjust existing events unless something important has changed.
        if event.nil? || meal_dirty?
          event ||= meal.events.build(calendar: resourcing.calendar)
          event.assign_attributes(event_attributes(resourcing))
        end
        current_events << event
      end
      meal.events.destroy(*(meal.events - current_events))
    end

    # Validates the event and copies errors to meal.
    # Assumes build_events has been run already.
    def validate_meal
      meal.events.each do |event|
        next if event.valid?

        errors = event.errors.map do |error|
          if error.attribute == :base
            error.message
          else
            "#{Calendars::Event.human_attribute_name(error.attribute)}: #{error.message}"
          end
        end.join(", ")
        meal.errors.add(:base,
                        "The following error(s) occurred in making a #{event.calendar_name} event " \
                        "for this meal: #{errors}.")
      end

      # Since we are copying these errors to the meal base, we don't need them in the
      # events base anymore.
      meal.errors.delete(:"events.base")
    end

    # Validates that changes to the event are valid with respect to the meal.
    def validate_event(event)
      return if meal.served_at.nil?

      if event.starts_at&.>(meal.served_at)
        event.errors.add(:starts_at, :after_meal_time, time: meal_time)
      elsif event.ends_at&.<(meal.served_at)
        event.errors.add(:ends_at, :before_meal_time, time: meal_time)
      end
    end

    # Updates the Resourcing associated with the event to reflect the new event times.
    # Assumes that validate_event has been called already and the changes are valid.
    def sync_resourcings(event)
      resourcing = meal.resourcings.detect { |r| r.calendar == event.calendar }
      raise ArgumentError, "Meal is not associated with calendar" if resourcing.nil?

      resourcing.update(
        prep_time: (meal.served_at - event.starts_at) / 1.minute,
        total_time: (event.ends_at - event.starts_at) / 1.minute
      )
    end

    private

    def event_attributes(resourcing)
      starts_at = meal.served_at - resourcing.prep_time.minutes
      {
        name: event_name,
        kind: "_meal",
        starts_at: starts_at,
        ends_at: starts_at + resourcing.total_time.minutes,
        guidelines_ok: "1"
      }
    end

    def meal_dirty?
      @meal_dirty ||= meal.new_record? || meal.will_save_change_to_served_at? ||
        meal.will_save_change_to_title?
    end

    def event_name
      prefix = "Meal:"
      title = truncate(meal.decorate.title_or_no_title,
                       length: Calendars::Event::NAME_MAX_LENGTH - prefix.size - 1, escape: false)
      "#{prefix} #{title}"
    end

    def settings
      @settings ||= meal.community.settings.calendars.meals
    end

    def meal_time
      I18n.l(meal.served_at, format: :time_only)
    end
  end
end
