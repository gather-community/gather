module Work
  class Job < ApplicationRecord
    TIMES_OPTIONS = %i(date_time date_only full_period)
    SLOT_TYPE_OPTIONS = %i(fixed full_single full_multiple)

    acts_as_tenant :cluster

    belongs_to :period, class_name: "Work::Period"
    belongs_to :requester, class_name: "People::Group"
    has_many :shifts, class_name: "Work::Shift", inverse_of: :job, dependent: :destroy

    scope :for_community, ->(c) { joins(:period).where("work_periods.community_id": c.id) }
    scope :by_title, -> { order("LOWER(title)") }
    scope :in_period, ->(p) { where(period_id: p.id) }
    scope :from_requester, ->(r) { where(requester: r) }

    normalize_attributes :title, :description

    before_validation :normalize

    validates :period, presence: true
    validates :title, presence: true, length: {maximum: 128}
    validates :hours, presence: true, numericality: {greater_than: 0}
    validates :time_type, presence: true
    validates :slot_type, presence: true
    validates :hours_per_shift, presence: true, if: :date_only_full_multiple?
    validates :description, presence: true
    validate :valid_shift_count
    validate :no_duplicate_start_end_times
    validate :shifts_same_length_for_date_time_full_multiple
    validate :hours_per_shift_evenly_divides_hours

    accepts_nested_attributes_for :shifts, reject_if: :all_blank, allow_destroy: true

    delegate :community, to: :period
    delegate :starts_on, :ends_on, :name, to: :period, prefix: true

    def full_period?
      time_type == "full_period"
    end

    def date_only?
      time_type == "date_only"
    end

    def date_time?
      time_type == "date_time"
    end

    def full_community?
      slot_type != "fixed"
    end

    def fixed_slot?
      slot_type == "fixed"
    end

    def full_group?
      slot_type != "fixed"
    end

    def full_single_slot?
      slot_type == "full_single"
    end

    def full_multiple_slot?
      slot_type == "full_multiple"
    end

    def date_only_full_multiple?
      date_only? && full_multiple_slot?
    end

    def slot_count
      shifts.sum(&:slots)
    end

    private

    def normalize
      self.hours_per_shift = nil unless date_only_full_multiple?
    end

    def shift_count
      @shift_count ||= shifts.reject(&:marked_for_destruction?).size
    end

    def valid_shift_count
      if shift_count == 0
        errors.add(:shifts, :no_shifts)
      elsif shift_count > 1 && full_single_slot?
        errors.add(:shifts, :more_than_one_shift_for_full_single)
      elsif shift_count > 1 && full_period?
        errors.add(:shifts, :more_than_one_shift_for_full_period)
      end
    end

    def no_duplicate_start_end_times
      if shifts.map { |s| [s.starts_at, s.ends_at] }.uniq.size < shifts.size
        errors.add(:shifts, :duplicate_start_end_times)
      end
    end

    def shifts_same_length_for_date_time_full_multiple
      if date_time? && full_multiple_slot? && shifts.map(&:elapsed_time).uniq.size != 1
        errors.add(:shifts, :different_length_shifts)
      end
    end

    def hours_per_shift_evenly_divides_hours
      if hours_per_shift.present? && hours % hours_per_shift != 0
        errors.add(:hours_per_shift, :uneven_divisor, hours: hours)
      end
    end
  end
end
