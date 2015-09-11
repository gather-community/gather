class Signup < ActiveRecord::Base
  MAX_PEOPLE_PER_TYPE = 10
  DINER_TYPES = %w(senior adult teen big_kid little_kid)
  FOOD_TYPES = %w(meat veg)
  SIGNUP_TYPES = DINER_TYPES.map{ |dt| FOOD_TYPES.map{ |ft| "#{dt}_#{ft}" } }.flatten

  belongs_to :meal
  belongs_to :household

  scope :sorted, -> { includes(household: :community).order('communities.abbrv, households.name') }

  normalize_attributes :comments

  validate :max_signups_per_type, :dont_exceed_spots

  delegate :full_name, to: :household, prefix: true

  def self.for(user, meal)
    find_or_initialize_by(household_id: user.household_id, meal_id: meal.id)
  end

  def self.total_for_meal(meal)
    where(meal_id: meal.id).sum(SIGNUP_TYPES.join("+"))
  end

  def save_or_destroy
    all_zero? ? (destroy if persisted?) : save
  end

  def total
    @total ||= SIGNUP_TYPES.inject(0){ |sum, t| sum += (send(t) || 0) }
  end

  def total_was
    SIGNUP_TYPES.inject(0){ |sum, t| sum += (send("#{t}_was") || 0) }
  end

  # The diff in the current total minus the total before the current update
  def total_change
    total - total_was
  end

  def all_zero?
    SIGNUP_TYPES.all?{ |t| self[t] == 0 }
  end

  def not_allowed?
    new_record? && !meal.signups_allowed?
  end

  private

  def max_signups_per_type
    SIGNUP_TYPES.each do |t|
      errors.add(t, "maximum of #{MAX_PEOPLE_PER_TYPE}") if send(t) > MAX_PEOPLE_PER_TYPE
    end
  end

  def dont_exceed_spots
    if total_change > meal.spots_left
      errors.add(:base, :exceeded_spots, count: meal.spots_left + total_was)
    end
  end
end
