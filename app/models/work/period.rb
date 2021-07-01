# frozen_string_literal: true

module Work
  # A subdivision of the community's work program based on a period of time.
  class Period < ApplicationRecord
    PHASE_OPTIONS = %i[draft ready open published archived].freeze
    QUOTA_TYPE_OPTIONS = %i[none by_person by_household].freeze
    PICK_TYPE_OPTIONS = %i[free_for_all staggered].freeze

    acts_as_tenant :cluster

    attr_accessor :job_copy_source_id

    belongs_to :community, inverse_of: :work_periods
    has_many :shares, inverse_of: :period, dependent: :destroy
    has_many :jobs, inverse_of: :period, dependent: :destroy

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :with_phase, ->(p) { where(phase: p) }
    scope :active, -> { where.not(phase: "archived") }
    scope :newest_first, -> { order(starts_on: :desc, ends_on: :desc) }
    scope :oldest_first, -> { order(:starts_on, :ends_on) }

    before_validation :normalize

    validates :name, :starts_on, :ends_on, presence: true
    validates :name, uniqueness: {scope: :community_id}
    validates :auto_open_time, presence: true, if: :staggered?
    validates :round_duration, presence: true, numericality: {greater_than: 0}, if: :staggered?
    validates :max_rounds_per_worker, presence: true, numericality: {greater_than: 0}, if: :staggered?
    validates :workers_per_round, presence: true, numericality: {greater_than: 0}, if: :staggered?
    validate :start_before_end

    accepts_nested_attributes_for :shares, reject_if: ->(s) { s[:portion].blank? }

    def self.new_with_defaults(community)
      new(
        community: community,
        phase: "draft",
        starts_on: (Time.zone.today + 1.month).beginning_of_month,
        ends_on: (Time.zone.today + 1.month).end_of_month,
        max_rounds_per_worker: 3,
        workers_per_round: 10,
        round_duration: 5
      )
    end

    PHASE_OPTIONS.each do |p|
      define_method :"#{p}?" do
        phase.to_sym == p
      end
    end

    QUOTA_TYPE_OPTIONS.each do |qt|
      define_method :"quota_#{qt}?" do
        quota_type.to_sym == qt
      end
    end

    def jobs?
      jobs.any?
    end

    def current?
      Time.zone.today >= starts_on && Time.zone.today <= ends_on
    end

    def future?
      Time.zone.today < starts_on
    end

    def pre_open?
      draft? || ready?
    end

    def staggered?
      pick_type == "staggered"
    end

    def free_for_all?
      pick_type == "free_for_all"
    end

    def auto_open_if_appropriate
      update!(phase: "open") if should_auto_open?
    end

    private

    def normalize
      shares.destroy_all if quota_none?
      self.phase = "open" if should_auto_open?
      self.pick_type = "free_for_all" if quota_none?
      return if staggered?
      self.round_duration = nil
      self.max_rounds_per_worker = nil
      self.workers_per_round = nil
    end

    def should_auto_open?
      auto_open_time? && pre_open? && Time.current >= auto_open_time
    end

    def start_before_end
      errors.add(:ends_on, :not_after_start) unless ends_on > starts_on
    end
  end
end
