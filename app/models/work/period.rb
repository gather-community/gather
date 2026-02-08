# frozen_string_literal: true

# == Schema Information
#
# Table name: work_periods
#
#  id                    :bigint           not null, primary key
#  auto_open_time        :datetime
#  cluster_id            :integer          not null
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  ends_on               :date             not null
#  max_rounds_per_worker :integer
#  meal_job_requester_id :bigint
#  meal_job_sync         :boolean          default(FALSE), not null
#  name                  :string           not null
#  phase                 :string           default("draft"), not null
#  pick_type             :string           default("free_for_all"), not null
#  quota                 :decimal(10, 2)   default(0.0), not null
#  quota_type            :string           default("none"), not null
#  round_duration        :integer
#  starts_on             :date             not null
#  updated_at            :datetime         not null
#  workers_per_round     :integer
#
module Work
  # A subdivision of the community's work program based on a period of time.
  class Period < ApplicationRecord
    include Wisper.model

    PHASE_OPTIONS = %i[draft ready open published archived].freeze
    QUOTA_TYPE_OPTIONS = %i[none by_person by_household].freeze
    PICK_TYPE_OPTIONS = %i[free_for_all staggered].freeze
    MEAL_JOB_SYNC_OPTIONS = %i[false true].freeze

    acts_as_tenant :cluster

    attr_accessor :job_copy_source_id
    attr_accessor :previous_meal_job_sync_setting_ids
    attr_accessor :copy_preassignments
    alias copy_preassignments? copy_preassignments

    belongs_to :community, inverse_of: :work_periods
    belongs_to :meal_job_requester, class_name: "Groups::Group",
                                    inverse_of: :work_periods_as_meal_job_requester
    has_many :shares, inverse_of: :period, dependent: :destroy

    # Deleting period shouldn't be possible for user if there are jobs within, but we still want to cascade
    # deletion for when system processes are destroying data.
    has_many :jobs, inverse_of: :period, dependent: :destroy

    has_many :meal_job_sync_settings, -> { includes(:formula, :role) },
             inverse_of: :period, dependent: :destroy

    scope :in_community, ->(c) { where(community: c) }
    scope :with_phase, ->(p) { where(phase: p) }
    scope :active, -> { where.not(phase: "archived") }
    scope :newest_first, -> { order(starts_on: :desc, ends_on: :desc, name: :asc) }
    scope :oldest_first, -> { order(:starts_on, :ends_on, :name) }
    scope :containing_date, ->(d) { where("starts_on <= ?", d).where("ends_on >= ?", d) }

    before_validation :normalize
    before_update :save_meal_job_sync_setting_ids

    validates :name, :starts_on, :ends_on, presence: true
    validates :name, uniqueness: {scope: :community_id}
    validates :auto_open_time, presence: true, if: :staggered?
    validates :round_duration, presence: true, numericality: {greater_than: 0}, if: :staggered?
    validates :max_rounds_per_worker, presence: true, numericality: {greater_than: 0}, if: :staggered?
    validates :workers_per_round, presence: true, numericality: {greater_than: 0}, if: :staggered?
    validate :start_before_end

    accepts_nested_attributes_for :meal_job_sync_settings, allow_destroy: true
    accepts_nested_attributes_for :shares, reject_if: ->(s) { s[:portion].blank? }

    def self.new_with_defaults(community)
      new(
        community: community,
        phase: "draft",
        starts_on: (Time.zone.today + 1.month).beginning_of_month,
        ends_on: (Time.zone.today + 1.month).end_of_month,
        max_rounds_per_worker: 3,
        workers_per_round: 10,
        round_duration: 5,
        copy_preassignments: true
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
      meal_job_sync_settings.each(&:mark_for_destruction) unless meal_job_sync?
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

    def save_meal_job_sync_setting_ids
      self.previous_meal_job_sync_setting_ids = meal_job_sync_settings.map(&:id).compact
    end
  end
end
