# frozen_string_literal: true

module Calendars
  # An event calendar.
  class Calendar < Node
    include AttachmentFormable
    include SemicolonDisallowable

    DEFAULT_CALENDAR_VIEWS = %i[week month].freeze
    COLORS = %w[#68adb1 #c67033 #910843 #d63679 #424ea8 #7c4d17 #a8982b #97a90e #308c58 #4795d3
                #2559aa #6e43a1 #a22084 #e42215 #e8590e #bc9300 #b5a803 #6faf49 #3e80c6 #e893be
                #3a231d #5b7827]

    belongs_to :group, class_name: "Calendars::Group", inverse_of: :calendars
    has_many :guideline_inclusions, class_name: "Calendars::GuidelineInclusion", dependent: :destroy
    has_many :shared_guidelines, through: :guideline_inclusions
    has_many :events, inverse_of: :calendar, class_name: "Calendars::Event",
                      dependent: :destroy
    has_many :protocolings, class_name: "Calendars::Protocoling", inverse_of: :calendar, dependent: :destroy
    has_many :protocols, through: :protocolings

    has_one_attached :photo
    accepts_attachment_via_form :photo

    normalize_attributes :color, with: :downcase

    validates :photo, content_type: {in: %w[image/jpg image/jpeg image/png image/gif]},
                      file_size: {max: Settings.photos.max_size_mb.megabytes}
    validates :abbrv, presence: true, if: :meal_hostable?
    validates :color, presence: true, format: {with: /\A#[0-9a-f]{6}\z/}

    disallow_semicolons :name

    scope :meal_hostable, -> { where(meal_hostable: true) }
    scope :non_system, -> { where(type: "Calendars::Calendar") }

    delegate :name, to: :community, prefix: true

    # Selects the least-used colors in the color set, for the given community
    def self.least_used_colors(community)
      counts = COLORS.index_with { |_c| 0 }
      in_community(community).each { |c| counts[c.color] += 1 if counts[c.color] }
      min_count = counts.values.min
      counts.map { |color, count| count == min_count ? color : nil }.compact
    end

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

    def photo?
      photo.attached?
    end

    def group?
      false
    end

    def system?
      false
    end

    def all_day_allowed?
      true
    end

    def in_group?
      group.present?
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
