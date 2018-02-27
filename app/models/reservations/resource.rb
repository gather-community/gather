module Reservations
  class Resource < ApplicationRecord
    include PhotoDestroyable, Deactivatable

    DEFAULT_CALENDAR_VIEWS = %i(week month)

    acts_as_tenant :cluster

    self.table_name = "resources"

    belongs_to :community
    has_many :guideline_inclusions, class_name: "Reservations::GuidelineInclusion", dependent: :destroy
    has_many :shared_guidelines, through: :guideline_inclusions
    has_many :reservations, class_name: "Reservations::Reservation", dependent: :destroy

    has_attached_file :photo,
      styles: { thumb: "220x165#" },
      default_url: "missing/reservations/resources/:style.png"
    validates_attachment_content_type :photo, content_type: %w(image/jpg image/jpeg image/png image/gif)
    validates_attachment_size :photo, less_than: (Settings.photos.max_size_mb || 8).megabytes

    validates :name, presence: true
    validates :abbrv, presence: true, if: :meal_hostable?

    scope :meal_hostable, -> { where(meal_hostable: true) }
    scope :by_cmty_and_name, -> { joins(:community).order("communities.abbrv, name") }
    scope :by_name, -> { order(:name) }
    scope :with_reservation_counts, -> { select("resources.*,
      (SELECT COUNT(id) FROM reservations WHERE resource_id = resources.id) AS reservation_count") }

    delegate :name, to: :community, prefix: true

    before_destroy do
      photo.destroy
    end

    # Available reservation kinds. Returns nil if none are defined.
    def kinds
      (community.settings.reservations.kinds || "").split(/\s*,\s*/).presence
    end

    def reservation_count
      attributes["reservation_count"] || reservations.count
    end

    def has_reservations?
      reservation_count > 0
    end

    def has_guidelines?
      all_guidelines.present?
    end

    # Concatenates own guidelines and shared guidelines together
    # Returns empty string if no guidelines.
    def all_guidelines
      return @all_guidelines if @all_guidelines

      own = guidelines.blank? ? nil : guidelines
      shared = shared_guidelines.map(&:body)
      all = ([own] + shared).compact.map(&:strip)
      @all_guidelines = all.join("\n\n---\n\n")
    end
  end
end
