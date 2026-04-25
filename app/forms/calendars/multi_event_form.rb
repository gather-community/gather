# frozen_string_literal: true

module Calendars
  class MultiEventForm
    NAME_MAX_LENGTH = Calendars::EventForm::NAME_MAX_LENGTH

    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include Rails.application.routes.url_helpers
    extend AttributeNormalizer::ClassMethods

    attr_accessor :name, :all_day, :starts_at, :ends_at, :note, :kind,
      :creator_id, :group_id, :sponsor_id, :origin_page, :guidelines_ok

    attr_reader :event, :calendar_slots

    normalize_attributes :kind, :note

    validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
    validates :starts_at, :ends_at, presence: true
    validate :calendar_slots_present
    validate :start_before_end
    validate :guidelines_accepted
    validate :per_slot_validations

    class << self
      def model_name
        Calendars::Event.model_name
      end

      # Cocoon calls reflect_on_association(:calendar_slots) to find the class for new records.
      # We handle :calendar_slots explicitly; delegate everything else to Event.
      def reflect_on_association(assoc)
        return OpenStruct.new(klass: Calendars::CalendarSlot, options: {}) if assoc == :calendar_slots
        Calendars::Event.reflect_on_association(assoc)
      end
    end

    # id.nil? and no event → new form (calendar_slots start empty)
    # id.present? → editing existing event; loads eventlets as CalendarSlots
    def initialize(action:, current_user:, id: nil, params: nil)
      @action = action
      @current_user = current_user

      if id.present?
        @event = Event.find(id)
        @calendar_slots = @event.eventlets.map { |el| eventlet_to_slot(el) }
        assign_event_fields(@event)
      else
        @event = Event.new(creator: current_user)
        @calendar_slots = []
      end

      apply_params(params) if params.present?
    end

    def valid?(*args)
      normalize
      super
    end

    def save
      return false unless valid?

      primary = active_slots.first
      @event.calendar = primary.calendar
      @event.dont_sync_eventlet = true
      @event.assign_attributes(event_attributes)

      Event.transaction do
        @event.save!
        sync_eventlets
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    def guidelines_ok? = guidelines_ok == "1"
    def all_day? = all_day.to_s.in?(%w[1 true])

    def all_guidelines
      active_slots.map(&:calendar).compact
        .select(&:guidelines?)
        .map(&:all_guidelines).uniq
        .join("\n\n---\n\n")
    end

    def any_guidelines? = all_guidelines.present?

    # Deterministic event-summary structs for rendering the Events section.
    def event_summaries
      active_slots.map do |slot|
        {
          calendar: slot.calendar,
          starts_at: slot.effective_starts_at(starts_at),
          ends_at: slot.effective_ends_at(ends_at)
        }
      end
    end

    def url
      @event.persisted? ? calendars_multi_event_path(@event) : calendars_multi_events_path
    end

    def persisted? = @event.persisted?
    def new_record? = @event.new_record?
    def id = @event.id

    private

    def active_slots = @calendar_slots.reject(&:marked_for_destruction?)

    def eventlet_to_slot(eventlet)
      main_times = eventlet.starts_at == @event.starts_at && eventlet.ends_at == @event.ends_at
      CalendarSlot.new(
        id: eventlet.id,
        calendar_id: eventlet.calendar_id,
        customize_times: main_times ? "0" : "1",
        starts_at: eventlet.starts_at,
        ends_at: eventlet.ends_at
      )
    end

    def assign_event_fields(ev)
      %i[name all_day starts_at ends_at note kind creator_id group_id sponsor_id].each do |a|
        public_send(:"#{a}=", ev.public_send(a))
      end
    end

    def apply_params(params)
      self.origin_page = params.delete(:origin_page)
      self.guidelines_ok = params.delete(:guidelines_ok)
      parse_datetime(:starts_at, params.delete(:starts_at))
      parse_datetime(:ends_at, params.delete(:ends_at))

      if (slots_attrs = params.delete(:calendar_slots_attributes)).present?
        @calendar_slots = build_slots_from_attrs(slots_attrs)
      end

      permitted = event_policy.permitted_attributes(group_id: params[:group_id])
      ap = params.is_a?(ActionController::Parameters) ? params : ActionController::Parameters.new(params)
      ap.permit(permitted - %i[starts_at ends_at origin_page guidelines_ok]).each do |k, v|
        public_send(:"#{k}=", v) if respond_to?(:"#{k}=")
      end
    end

    def build_slots_from_attrs(attrs)
      attrs.values.map do |raw|
        a = (raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw).with_indifferent_access
        CalendarSlot.new(
          id: a[:id],
          calendar_id: a[:calendar_id],
          customize_times: a[:customize_times],
          starts_at: parse_time(a[:starts_at]),
          ends_at: parse_time(a[:ends_at]),
          _destroy: a[:_destroy]
        )
      end
    end

    def parse_datetime(attr, value)
      return if value.blank?
      public_send(:"#{attr}=", Time.zone.parse(value.to_s))
    end

    def parse_time(value) = value.present? ? Time.zone.parse(value.to_s) : nil

    def event_attributes
      attrs = {name: name, all_day: all_day?, starts_at: starts_at, ends_at: ends_at,
               note: note, kind: kind, group_id: group_id, sponsor_id: sponsor_id}
      attrs[:creator_id] = creator_id if creator_id.present?
      attrs
    end

    def sync_eventlets
      existing_by_id = @event.eventlets.reload.index_by(&:id)
      active_slots.each { |s| write_eventlet(s, existing_by_id) }
      @calendar_slots.select(&:marked_for_destruction?).each do |slot|
        existing_by_id[slot.id.to_i]&.destroy!
      end
    end

    def write_eventlet(slot, existing_by_id)
      eventlet = find_or_build_eventlet(slot, existing_by_id)
      eventlet.calendar_id = slot.calendar_id
      eventlet.starts_at = slot.effective_starts_at(starts_at)
      eventlet.ends_at = slot.effective_ends_at(ends_at)
      eventlet.all_day = all_day?
      eventlet.save!
    end

    def find_or_build_eventlet(slot, existing_by_id)
      return @event.eventlets.build if slot.id.blank?
      existing_by_id[slot.id.to_i] || @event.eventlets.build
    end

    def normalize
      return unless all_day?
      self.starts_at = starts_at&.midnight
      self.ends_at = ends_at&.midnight&.+(1.day - 1.second)
    end

    def calendar_slots_present
      return if active_slots.any?
      errors.add(:base, "At least one calendar must be selected")
    end

    def start_before_end
      return unless starts_at.present? && ends_at.present? && starts_at >= ends_at
      errors.add(:ends_at, "must be after start time")
    end

    def guidelines_accepted
      return unless new_record? && any_guidelines? && !guidelines_ok?
      errors.add(:guidelines, "You must agree to the guidelines")
    end

    def per_slot_validations
      active_slots.each do |slot|
        next if slot.calendar.nil?
        slot_starts = slot.effective_starts_at(starts_at)
        slot_ends = slot.effective_ends_at(ends_at)
        next if slot.calendar.allow_overlap? || slot_starts.blank? || slot_ends.blank?
        query = Event.between(slot_starts..slot_ends).where(calendar_id: slot.calendar_id)
        query = query.where.not(id: @event.id) if persisted?
        errors.add(:base, "#{slot.calendar.name}: overlaps an existing event") if query.exists?
      end
    end

    def event_policy
      @event_policy ||= Calendars::EventPolicy.new(@current_user, @event)
    end
  end
end
