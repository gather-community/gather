module Work
  class Period < ApplicationRecord
    PHASE_OPTIONS = %i[draft open pending published archived]
    QUOTA_TYPE_OPTIONS = %i[none by_person by_household]

    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :work_periods
    has_many :shares, inverse_of: :period, dependent: :destroy
    has_many :jobs, inverse_of: :period, dependent: :destroy

    scope :for_community, ->(c) { where(community_id: c.id) }
    scope :with_phase, ->(p) { where(phase: p) }
    scope :active, -> { where.not(phase: "archived") }
    scope :latest_first, -> { order(starts_on: :desc, ends_on: :desc) }

    before_validation :normalize

    validates :name, :starts_on, :ends_on, presence: true
    validates :name, uniqueness: {scope: :community_id}
    validate :start_before_end

    accepts_nested_attributes_for :shares, reject_if: ->(s) { s[:portion].blank? }

    def self.new_with_defaults(community)
      new(
        community: community,
        phase: "draft",
        starts_on: (Date.today + 1.month).beginning_of_month,
        ends_on: (Date.today + 1.month).end_of_month
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

    private

    def normalize
      shares.destroy_all if quota_none?
    end

    def start_before_end
      errors.add(:ends_on, :not_after_start) unless ends_on > starts_on
    end
  end
end
