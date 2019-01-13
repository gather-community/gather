# frozen_string_literal: true

module Work
  # Models an archetype of a job that can be instantiated for a given period.
  # Used heavily in meals-work integration.
  class JobTemplate < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
    belongs_to :requester, class_name: "People::Group"
    has_many :reminder_templates, class_name: "Work::ReminderTemplate", inverse_of: :job_template

    scope :by_title, -> { alpha_order(:title) }
    scope :in_community, ->(c) { where(community_id: c.id) }

    normalize_attributes :title, :description

    before_validation :normalize

    validates :title, presence: true, length: {maximum: 128}, uniqueness: {scope: :community_id}
    validates :hours, presence: true, numericality: {greater_than: 0}
    validates :time_type, presence: true
    validates :description, presence: true
    validates :shift_start, presence: true, if: :meal_related_and_date_time?
    validates :shift_end, presence: true, if: :meal_related_and_date_time?
    validate :shift_time_positive

    accepts_nested_attributes_for :reminder_templates, reject_if: :all_blank, allow_destroy: true

    private

    def normalize
      if meal_related_and_date_time?
        self.hours = (shift_end - shift_start).to_f / 60 if shift_start.present? && shift_end.present?
      else
        self.shift_start = nil
        self.shift_end = nil
      end
    end

    # Sets a validation message on shift_end if shift_start and shift_end are given and
    # and the resulting elapsed time is not positive. This would also raise an error on hours
    # but if these are set, hours is not visible.
    def shift_time_positive
      return unless shift_start.present? && shift_end.present? && !(shift_end - shift_start).positive?
      errors.add(:shift_end, :not_after_start)
    end

    def meal_related_and_date_time?
      meal_related? && time_type == "date_time"
    end
  end
end
