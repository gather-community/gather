class Formula < ActiveRecord::Base

  # Finds the most recent formula associated with the given meal.
  # Returns nil if none found.
  def self.for_meal(meal)
    where("effective_on <= ?", meal.served_at.to_date).
      where(community_id: meal.host_community_id).
      order(effective_on: :desc).first
  end

  def allows_diner_type?(diner_type)
    Signup::SIGNUP_TYPES.any?{ |st| st =~ /^#{diner_type}_/ && send("#{st}").present? }
  end

  def allows_signup_type?(diner_type, meal_type)
    !send("#{diner_type}_#{meal_type}").nil?
  end
end
