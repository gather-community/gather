# frozen_string_literal: true

module Reservations
  # Something that can be reserved.
  class Resource < ApplicationRecord
    include Deactivatable
    include AttachmentFormable

    DEFAULT_CALENDAR_VIEWS = %i[week month].freeze

    acts_as_tenant :cluster

    self.table_name = "resources"

    belongs_to :community
    has_many :guideline_inclusions, class_name: "Reservations::GuidelineInclusion", dependent: :destroy
    has_many :shared_guidelines, through: :guideline_inclusions
    has_many :reservations, inverse_of: :resource, class_name: "Reservations::Reservation",
                            dependent: :destroy

    has_one_attached :photo

    validates :name, presence: true, uniqueness: {scope: :community_id}
    validates :abbrv, presence: true, if: :meal_hostable?

    scope :in_community, ->(c) { where(community: c) }
    scope :meal_hostable, -> { where(meal_hostable: true) }
    scope :by_cmty_and_name, -> { joins(:community).order("communities.abbrv, name") }
    scope :by_name, -> { alpha_order(:name) }
    scope :with_reservation_counts, lambda {
      select("resources.*, (SELECT COUNT(id) FROM reservations
        WHERE resource_id = resources.id) AS reservation_count")
    }

    delegate :name, to: :community, prefix: true

    # Available reservation kinds. Returns nil if none are defined.
    def kinds
      (community.settings.reservations.kinds || "").split(/\s*,\s*/).presence
    end

    def reservation_count
      attributes["reservation_count"] || reservations.count
    end

    def reservations?
      reservation_count.positive?
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
