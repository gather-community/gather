class Work::Shift < ApplicationRecord
  belongs_to :job, class_name: "Work::Job", inverse_of: :shifts

  delegate :full_period?, :full_community?, :shifts_have_times?, to: :job, prefix: true
  delegate :period_starts_on, :period_ends_on, to: :job

  before_validation :normalize

  validates :starts_at, :ends_at, presence: true, unless: :job_full_period?
  validates :slots, presence: true, numericality: {greater_than: 0}
  validate :start_before_end

  def min_time
    period_starts_on.midnight
  end

  def max_time
    (period_ends_on + 1).midnight
  end

  private

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
end
