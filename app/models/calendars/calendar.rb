# frozen_string_literal: true

module Calendars
  # An event calendar.
  class Calendar < Node
    include Deactivatable
    include AttachmentFormable
    include SemicolonDisallowable

    DEFAULT_CALENDAR_VIEWS = %i[week month].freeze

    has_many :guideline_inclusions, class_name: "Calendars::GuidelineInclusion", dependent: :destroy
    has_many :shared_guidelines, through: :guideline_inclusions
    has_many :events, inverse_of: :calendar, class_name: "Calendars::Event",
                      dependent: :destroy
    has_many :protocolings, class_name: "Calendars::Protocoling", inverse_of: :calendar,
                            foreign_key: "calendar_id", dependent: :destroy
    has_many :protocols, through: :protocolings

    has_one_attached :photo
    accepts_attachment_via_form :photo
    validates :photo, content_type: {in: %w[image/jpg image/jpeg image/png image/gif]},
                      file_size: {max: Settings.photos.max_size_mb.megabytes}

    validates :abbrv, presence: true, if: :meal_hostable?

    disallow_semicolons :name

    scope :meal_hostable, -> { where(meal_hostable: true) }
    scope :with_event_counts, lambda {
      select("calendar_nodes.*, (SELECT COUNT(id) FROM calendar_events
        WHERE calendar_id = calendar_nodes.id) AS event_count")
    }

    delegate :name, to: :community, prefix: true

    # Available event kinds. Returns nil if none are defined.
    def kinds
      (community.settings.calendars.kinds || "").split(/\s*,\s*/).presence
    end

    def event_count
      attributes["event_count"] || events.count
    end

    def events?
      event_count.positive?
    end

    def guidelines?
      all_guidelines.present?
    end

    # Concatenates own guidelines and shared guidelines together
    # Returns empty string if no guidelines.
    def all_guidelines
      return @all_guidelines if @all_guidelines

      own = guidelines.presence
      shared = shared_guidelines.map(&:body)
      all = ([own] + shared).compact.map(&:strip)
      @all_guidelines = all.join("\n\n---\n\n")
    end
  end
end
