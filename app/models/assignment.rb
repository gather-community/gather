# frozen_string_literal: true

class Assignment < ApplicationRecord
  ROLES = %w[head_cook asst_cook table_setter cleaner].freeze # In order
  ALL_EXTRA_ROLES = %i[asst_cook table_setter cleaner].freeze

  acts_as_tenant :cluster

  scope :oldest_first, -> { joins(:meal).order("meals.served_at") }

  belongs_to :user, inverse_of: :meal_assignments
  belongs_to :meal, inverse_of: :assignments

  def self.by_role
    array_inner = ROLES.map { |r| "'#{r}'" }.join(",")
    order("ARRAY_POSITION(ARRAY[#{array_inner}], role::text)")
  end

  def empty?
    user_id.blank?
  end

  def starts_at
    meal.served_at + shift_time_offset(:start)
  end

  def ends_at
    meal.served_at + shift_time_offset(:end)
  end

  def title
    I18n.t("assignment_roles.#{role}", count: 1) << ": " << meal.title_or_no_title
  end

  def <=>(other)
    ROLES.index(role) <=> ROLES.index(other.role)
  end

  private

  def shift_time_offset(start_or_end)
    meal.community.settings.meals.default_shift_times[start_or_end][role].minutes
  end
end
