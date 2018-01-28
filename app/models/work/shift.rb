class Work::Shift < ApplicationRecord
  belongs_to :job, class_name: "Work::Job", inverse_of: :shifts

  validates :starts_at, :ends_at, presence: true, unless: :job_full_period?

  private

  delegate :full_period?, to: :job, prefix: true
end
