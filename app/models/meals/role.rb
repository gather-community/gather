# frozen_string_literal: true

module Meals
  # Meal roles are types of jobs for meals like head cook, assistant cook, etc.
  class Role < ApplicationRecord
    include Deactivatable

    TIMES_OPTIONS = %i[date_time date_only].freeze

    acts_as_tenant :cluster

    belongs_to :community
    has_many :reminders, -> { canonical_order }, class_name: "Meals::RoleReminder", dependent: :destroy,
                                                 foreign_key: :meal_role_id, inverse_of: :role

    scope :by_title, -> { alpha_order(:title) }
    scope :in_community, ->(c) { where(community_id: c.id) }

    normalize_attributes :title, :description

    before_validation :normalize

    validates :title, presence: true, length: {maximum: 128},
                      uniqueness: {scope: %i[community_id deactivated_at]}
    validates :count_per_meal, presence: true
    validates :time_type, presence: true
    validates :description, presence: true
    validates :shift_start, presence: true, if: :date_time?
    validates :shift_end, presence: true, if: :date_time?
    validate :shift_time_positive

    accepts_nested_attributes_for :reminders, reject_if: :all_blank, allow_destroy: true

    def head_cook?
      special == "head_cook"
    end

    private

    def normalize
      unless date_time?
        self.shift_start = nil
        self.shift_end = nil
      end
      self.count_per_meal = 1 if head_cook?
    end

    # Sets a validation message on shift_end if shift_start and shift_end are given and
    # and the resulting elapsed time is not positive. This would also raise an error on hours
    # but if these are set, hours is not visible.
    def shift_time_positive
      return unless shift_start.present? && shift_end.present? && !(shift_end - shift_start).positive?
      errors.add(:shift_end, :not_after_start)
    end

    def date_time?
      time_type == "date_time"
    end
  end
end
