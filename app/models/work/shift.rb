class Work::Shift < ApplicationRecord
  belongs_to :job, class_name: "Work::Job", inverse_of: :shifts

  delegate :hours, :slot_type, :full_period?, :full_community?, :shifts_have_times?, to: :job, prefix: true
  delegate :period_starts_on, :period_ends_on, to: :job

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

  private

  def elapsed_time
    @elapsed_time ||= ends_at - starts_at
  end

  def normalize
    self.slots = 1e6 if job_full_community?

    unless job_shifts_have_times?
      self.starts_at = starts_at.midnight
      self.ends_at = ends_at.midnight
    end
  end

  def start_before_end
    errors.add(:ends_at, :not_after_start) unless ends_at > starts_at
  end

  def elapsed_hours_must_equal_job_hours
    if job_shifts_have_times?
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
