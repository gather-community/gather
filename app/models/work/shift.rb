class Work::Shift < ApplicationRecord
  # We set touch: true so that shift changes will update the job updated_at stamp, which
  # we use in a cache key.
  belongs_to :job, class_name: "Work::Job", inverse_of: :shifts, touch: true
  has_many :assignments, class_name: "Work::Assignment", inverse_of: :shift, dependent: :destroy

  delegate :hours, :slot_type, :date_time?, :date_only?, :full_period?,
    :full_community?, to: :job, prefix: true
  delegate :community, :period_starts_on, :period_ends_on, to: :job

  before_validation :normalize

  validates :starts_at, :ends_at, presence: true, unless: :job_full_period?
  validates :slots, presence: true, numericality: {greater_than: 0}
  validate :start_before_end
  validate :elapsed_hours_must_equal_job_hours

  def min_time
    period_starts_on.midnight
  end

  def max_time
    (period_ends_on + 1).midnight
  end

  def hours
    if job.date_only_full_multiple?
      job.hours_per_shift
    elsif job.full_multiple_slot?
      elapsed_time / 1.hour
    else
      job_hours
    end
  end

  def all_slots_taken?
    assignments.size >= slots
  end

  def elapsed_time
    @elapsed_time ||= ends_at - starts_at
  end

  private

  def normalize
    self.slots = 1e6 if job_full_community?

    if job_full_period?
      self.starts_at = period_starts_on.in_time_zone
      self.ends_at = period_ends_on.in_time_zone + 1.day - 1.minute
    elsif job_date_only?
      self.starts_at = starts_at.midnight
      self.ends_at = ends_at.midnight + 1.day - 1.minute
    end
  end

  def start_before_end
    errors.add(:ends_at, :not_after_start) unless ends_at > starts_at
  end

  def elapsed_hours_must_equal_job_hours
    if job_date_time?
      if job_slot_type == "full_multiple"
        unless job_hours.hours % elapsed_time == 0
          errors.add(:starts_at, :elapsed_doesnt_evenly_divide_job, hours: job_hours)
        end
      else
        unless elapsed_time == job_hours.hours
          errors.add(:starts_at, :elapsed_doesnt_equal_job, hours: job_hours)
        end
      end
    end
  end
end
