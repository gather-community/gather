# frozen_string_literal: true

module Work
  class SlotsExceededError < StandardError; end
  class AlreadySignedUpError < StandardError; end
  class NotSignedUpError < StandardError; end

  # Represents one timed occurrence of a job.
  class Shift < ApplicationRecord
    UNLIMITED_SLOTS = 1e6

    acts_as_tenant :cluster

    # We set touch: true so that shift changes will update the job updated_at stamp, which
    # we use in a cache key.
    belongs_to :job, class_name: "Work::Job", inverse_of: :shifts, touch: true
    has_many :assignments, -> { by_user_name }, class_name: "Work::Assignment",
                                                inverse_of: :shift, dependent: :destroy

    delegate :title, :hours, :requester, :description, :slot_type, :date_time?, :date_only?,
      :full_period?, :full_community?, to: :job, prefix: true
    delegate :community, :period, :period_name,
      :period_draft?, :period_open?, :period_pending?, :period_published?, :period_archived?,
      :period_starts_on, :period_ends_on, to: :job

    scope :by_time, -> { order(:starts_at, :ends_at) }
    scope :for_community, ->(c) { joins(job: :period).where("work_periods.community_id": c.id) }
    scope :in_period, ->(p) { joins(:job).where("work_jobs.period_id": p.id) }
    scope :by_job_title, -> { joins(:job).order("LOWER(work_jobs.title)") }
    scope :by_date, -> { order(:starts_at, :ends_at) }
    scope :from_requester, ->(r) { joins(:job).where("work_jobs.requester_id": r) }
    scope :open, lambda {
      where("(SELECT COUNT(*) FROM work_assignments
        WHERE work_assignments.shift_id = work_shifts.id) < slots")
    }
    scope :with_user, lambda { |users|
      where("EXISTS (SELECT id FROM work_assignments
        WHERE work_assignments.shift_id = work_shifts.id AND work_assignments.user_id IN (?))",
        Array.wrap(users).map(&:id))
    }
    scope :matching, lambda { |search|
      joins(:job, "LEFT OUTER JOIN people_groups ON people_groups.id = work_jobs.requester_id")
        .where("
          work_jobs.title ILIKE ?
            OR people_groups.name ILIKE ?
            OR EXISTS (SELECT id FROM users WHERE id IN (
              SELECT user_id FROM work_assignments
                WHERE shift_id = work_shifts.id AND (first_name ILIKE ? OR last_name ILIKE ?)))",
          *(["%#{search}%"] * 4))
    }
    scope :with_non_preassigned_or_empty_slots, lambda {
      where("(SELECT COUNT(id) FROM work_assignments
        WHERE work_assignments.shift_id = work_shifts.id AND work_assignments.preassigned = 't') < slots")
    }

    before_validation :normalize

    validates :starts_at, :ends_at, presence: true, unless: :job_full_period?
    validates :slots, presence: true, numericality: {greater_than: 0}
    validate :start_before_end
    validate :elapsed_hours_must_equal_job_hours
    validate :no_double_assignments

    accepts_nested_attributes_for :assignments, allow_destroy: true

    # Make it so assignments with no user ID are destroyed.
    def assignments_attributes=(attribs)
      attribs.each_value { |a| a[:_destroy] = 1 if a[:user_id].blank? }
      super(attribs)
    end

    def min_time
      period_starts_on.midnight
    end

    def max_time
      (period_ends_on + 1).midnight
    end

    # Shift hours can be different than job hours (specifically for full community jobs).
    def hours
      if job.date_only_full_multiple?
        job.hours_per_shift
      elsif job.full_multiple_slot?
        elapsed_time / 1.hour
      else
        job_hours
      end
    end

    def taken?
      assignments_count >= slots
    end

    def preassignments?
      assignments.any?(&:preassigned?)
    end

    def starts_and_ends_on_month_boundaries?
      starts_at_date.beginning_of_month == starts_at_date && ends_at_date.end_of_month == ends_at_date
    end

    def empty_slots
      @empty_slots ||= job_full_community? ? UNLIMITED_SLOTS : [slots - assignments_count, 0].max
    end

    def elapsed_time
      @elapsed_time ||= starts_at.nil? || ends_at.nil? ? nil : ends_at - starts_at
    end

    # Creates an assignment for the given user.
    # Ensures max slots are not exceeded by competing writes.
    # Raises a Work::SlotsExceededError if no slots left.
    # Raises a Work::AlreadySignedUpError if no that user already signed up for this shift.
    def signup_user(user)
      repeatable_read_transaction_with_retries do
        raise Work::SlotsExceededError if current_assignments_count >= slots
        raise Work::AlreadySignedUpError if user_signed_up?(user)
        assignments.create!(user_id: user.id)
      end
    end

    def unsignup_user(user)
      assignment = assignment_for_user(user)
      raise Work::NotSignedUpError unless assignment
      assignment.destroy
    end

    def user_signed_up?(user)
      assignment_for_user(user).present?
    end

    def assignment_for_user(user)
      assignments.detect { |a| a.user_id == user.id }
    end

    private

    # Re-retrieves assignments_count so that we have the most recent data.
    def current_assignments_count
      reload.assignments_count
    end

    def normalize
      if job_full_community?
        self.slots = UNLIMITED_SLOTS
      else
        # Remove any extra assignments beyond the permitted slots.
        assignments.delete(*assignments.reject(&:marked_for_destruction?)[slots..-1]) if slots.present?
      end

      if job_full_period?
        self.starts_at = period_starts_on.in_time_zone
        self.ends_at = period_ends_on.in_time_zone + 1.day - 1.minute
      elsif job_date_only?
        self.starts_at = starts_at.midnight
        self.ends_at = ends_at.midnight + 1.day - 1.minute
      end
    end

    def start_before_end
      return unless starts_at.present? && ends_at.present? && ends_at <= starts_at
      errors.add(:ends_at, :not_after_start)
    end

    def elapsed_hours_must_equal_job_hours
      return unless job_date_time? && job_hours.present?
      if job_slot_type == "full_multiple"
        unless (job_hours.hours % elapsed_time).zero?
          errors.add(:starts_at, :elapsed_doesnt_evenly_divide_job, hours: job_hours)
        end
      else
        unless elapsed_time == job_hours.hours
          errors.add(:starts_at, :elapsed_doesnt_equal_job, hours: job_hours)
        end
      end
    end

    def no_double_assignments
      user_ids = assignments.reject(&:marked_for_destruction?).map(&:user_id)
      return if user_ids.size == user_ids.uniq.size
      errors.add(:assignments, :no_double_assignments)
    end

    def starts_at_date
      @starts_at_date ||= starts_at.to_date
    end

    def ends_at_date
      @ends_at_date ||= ends_at.to_date
    end
  end
end
