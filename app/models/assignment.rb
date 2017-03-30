class Assignment < ActiveRecord::Base
  ROLES = %w(head_cook asst_cook table_setter cleaner) # In order

  belongs_to :user
  belongs_to :meal

  delegate :location_name, to: :meal

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
    meal.host_community.config.meals.default_shift_times[start_or_end][role].minutes
  end
end
