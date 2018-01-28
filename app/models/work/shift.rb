class Work::Shift < ApplicationRecord
  belongs_to :job, class_name: "Work::Job", inverse_of: :shifts

  validates :starts_at, :ends_at, presence: true, unless: :job_full_period?

  delegate :full_period?, to: :job, prefix: true
  delegate :period_starts_on, :period_ends_on, to: :job

  def min_time
    period_starts_on.midnight
  end

  def max_time
    (period_ends_on + 1).midnight
  end
end
