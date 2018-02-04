module Work
  class Job < ApplicationRecord
    TIMES_OPTIONS = %i(date_time date_only full_period)
    SLOT_TYPE_OPTIONS = %i(fixed full_single full_multiple)

    acts_as_tenant :cluster

    belongs_to :community
    belongs_to :period, class_name: "Work::Period"
    belongs_to :requester, class_name: "People::Group"
    has_many :shifts, class_name: "Work::Shift", inverse_of: :job

    scope :for_community, ->(c) { where(community_id: c.id) }

    normalize_attributes :title, :description

    validates :period, presence: true
    validates :title, presence: true, length: {maximum: 128}
    validates :hours, presence: true, numericality: {greater_than: 0}
    validates :time_type, presence: true
    validates :slot_type, presence: true
    validates :description, presence: true
    validate :valid_shift_count
    validate :no_duplicate_start_end_times
    validate :shifts_same_length_for_date_time_full_multiple

    accepts_nested_attributes_for :shifts, reject_if: :all_blank, allow_destroy: true

    delegate :starts_on, :ends_on, to: :period, prefix: true

    def full_period?
      time_type == "full_period"
    end

    def shifts_have_times?
      time_type == "date_time"
    end

    def full_community?
      slot_type != "fixed"
    end

    def full_community?
      slot_type != "fixed"
    end

    def fixed_slot?
      slot_type == "fixed"
    end

    def full_single_slot?
      slot_type == "full_single"
    end

    def full_multiple_slot?
      slot_type == "full_multiple"
    end

    private

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
      if shifts_have_times? && full_multiple_slot? && shifts.map(&:elapsed_time).uniq.size != 1
        errors.add(:shifts, :different_length_shifts)
      end
    end
  end
end
