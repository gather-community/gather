# frozen_string_literal: true

module Calendars
  class EventForm
    NAME_MAX_LENGTH = 24

    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include Rails.application.routes.url_helpers
    extend AttributeNormalizer::ClassMethods

    # These are persisted attributes that are persisted to the database.
    delegate :starts_at, :ends_at, :note, :name, :kind, :sponsor_id, :all_day, :creator_id, :group_id, to: :event

    # These are ephemeral attributes that are not persisted to the database.
    # origin_page tracks the page that the event was created from, so we can redirect back to it after creation.
    # guidelines_ok tracks whether the user has accepted the guidelines, and is used for validation only.
    attr_accessor :origin_page, :guidelines_ok

    alias :all_day? :all_day

    attr_reader :event

    delegate :creator, to: :event

    normalize_attributes :kind, :note

    validates :name, presence: true, length: {maximum: NAME_MAX_LENGTH}
    validates :starts_at, :ends_at, presence: true
    validate :guidelines_accepted
    validate :start_before_end
    validate :restrict_changes_in_past
    validate :no_overlap
    validate :apply_rules
    validate lambda { |r| meal&.event_handler&.validate_event(r.event) }

    class << self
      delegate :reflect_on_association, to: Event
    end

    def self.model_name
      Calendars::Event.model_name
    end

    # If not passing an id or event object, current_user and params.calendar_id are required,
    # and a new event will be initialized with default parameters.
    #
    # params is not required when instantiating for the purpose of #new and #edit.
    # params is also not required if passing an already-constructed event object.
    # params is a hash of parameters that will be used to initialize the event.
    # params can be a regular Hash or an ActionController::Parameters object.
    #
    # This method will filter permitted attributes based on the policy for the event.
    def initialize(action: nil, current_user: nil, event: nil, id: nil, params: nil)
      @current_user = current_user
      @action = action

      # If we need to build an event object, we set the calendar on it so we can pass it to the policy object.
      if id.nil? && event.nil?
        calendar_id = params.delete(:calendar_id)
        raise "current_user and params[:calendar_id] are required when not passing an event" if current_user.nil? || calendar_id.nil?

        @event = Event.new(creator: current_user)
        @event.calendar = Calendar.find(calendar_id)
      elsif event.present?
        @event = event
      else
        @event = Event.find(id)
      end

      parse_starts_and_ends_at(params)
      set_default_starts_and_ends_at(params) if @action == :new

      if params.present?
        permitted_attributes = event_policy.permitted_attributes(group_id: params[:group_id])
        unless params.is_a?(ActionController::Parameters)
          params = ActionController::Parameters.new(params)
        end
        self.origin_page = params.delete(:origin_page)
        self.guidelines_ok = params.delete(:guidelines_ok)
        @event.assign_attributes(params.permit(permitted_attributes))
      end
    end

    def valid?(*args)
      normalize

      super(*args)
    end

    def save
      return false unless valid?
      @event.save
    end

    def guidelines_ok?
      guidelines_ok == "1"
    end

    def url
      if %i[new create].include?(@action)
        calendars_events_path
      else
        calendars_event_path(@event)
      end
    end

    private

    delegate(
      :calendar_allows_overlap?,
      :calendar_id,
      :calendar,
      :id,
      :meal,
      :meal?,
      :new_record?,
      :persisted?,
      :recently_created?,
      :rule_set,
      :starts_at_was,
      :will_save_change_to_starts_at?,
      :will_save_change_to_ends_at?,
      to: :event
    )

    def event_policy
      @event_policy ||= EventPolicy.new(@current_user, @event)
    end

    def parse_starts_and_ends_at(params)
      if params.present?
        # Parse the starts_at and ends_at from the params if they are present.
        # We delete them because we don't want to call super with them
        # because then they would overwrite the values we may set in set_default_starts_and_ends_at.
        starts_at_param = params.delete(:starts_at)
        ends_at_param = params.delete(:ends_at)
        @event.starts_at = Time.zone.parse(starts_at_param) if starts_at_param.present?
        @event.ends_at = Time.zone.parse(ends_at_param) if ends_at_param.present?
      end
    end

    def set_default_starts_and_ends_at(params)
      # If no initial starts_at and ends_at were provided, set the default values.
      @event.starts_at ||= Time.current.midnight + 1.week + 17.hours
      @event.ends_at ||= Time.current.midnight + 1.week + 18.hours

      # If the rule set has a fixed start/end time, use it.
      # This should override the default values if they are present.
      rule_set = @event.rule_set
      if fst = rule_set.fixed_start_time
        @event.starts_at = starts_at.change(hour: fst.hour, min: fst.min)
      end
      if fet = rule_set.fixed_end_time
        @event.ends_at = ends_at.change(hour: fet.hour, min: fet.min)
      end
      if fst && fet && starts_at >= ends_at
        @event.ends_at += 1.day
      end
    end

    def normalize
      @event.all_day = false if rule_set.timed_events_only?
      return unless all_day?
      @event.starts_at = starts_at.midnight
      @event.ends_at = ends_at.midnight + 1.day - 1.second
    end

    def guidelines_accepted
      return unless new_record? && calendar.guidelines? && !guidelines_ok?
      errors.add(:guidelines, "You must agree to the guidelines")
    end

    def start_before_end
      return unless starts_at.present? && ends_at.present? && starts_at >= ends_at
      errors.add(:ends_at, "must be after start time")
    end

    def no_overlap
      return if calendar_allows_overlap? || starts_at.blank? || ends_at.blank?
      query = Event.between(starts_at..ends_at)
      query = query.where(calendar_id: calendar_id)
      query = query.where("id != #{id}") if persisted?
      errors.add(:base, "This event overlaps an existing one") if query.any?
    end

    def apply_rules
      return if errors.any?
      rule_set.errors(self).each { |e| errors.add(*e) }
    end

    def restrict_changes_in_past
      return unless persisted? && !recently_created? && !event_policy.privileged_change?
      if will_save_change_to_starts_at? && starts_at_was&.past?
        errors.add(:starts_at, "can't be changed after event begins")
      end
      if will_save_change_to_ends_at? && ends_at&.past? # rubocop:disable Style/GuardClause # || structure
        errors.add(:ends_at, "can't be changed to a time in the past")
      end
    end
  end
end