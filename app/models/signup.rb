# frozen_string_literal: true

# Models information about one household's attendance at a meal.
class Signup < ApplicationRecord
  MAX_PEOPLE_PER_TYPE = 10
  MAX_COMMENT_LENGTH = 500
  DINER_TYPES = %w[adult senior teen big_kid little_kid].freeze
  FOOD_TYPES = %w[meat veg].freeze
  SIGNUP_TYPES = DINER_TYPES.map { |dt| FOOD_TYPES.map { |ft| "#{dt}_#{ft}" } }.flatten
  VEG_SIGNUP_TYPES = DINER_TYPES.map { |dt| "#{dt}_veg" }
  PORTION_FACTORS = {
    senior: 0.75,
    adult: 1,
    teen: 0.75,
    big_kid: 0.5,
    little_kid: 0
  }.freeze

  acts_as_tenant :cluster

  belongs_to :meal, inverse_of: :signups
  belongs_to :household

  scope :community_first, lambda { |c|
    includes(household: :community).order("CASE WHEN communities.id = #{c.id} THEN 0 ELSE 1 END")
  }
  scope :sorted, -> { joins(household: :community).order("communities.abbrv, households.name") }

  normalize_attributes :comments

  validates :household_id, presence: true, uniqueness: {scope: :meal_id}
  validates :comments, length: {maximum: MAX_COMMENT_LENGTH}
  validate :max_signups_per_type
  validate :dont_exceed_spots
  validate :nonzero_signups_if_new

  delegate :name, :users, :adults, to: :household, prefix: true
  delegate :community_abbrv, to: :household
  delegate :communities, to: :meal

  before_update do
    destroy if all_zero?
  end

  def self.for(user, meal)
    find_or_initialize_by(household_id: user.household_id, meal_id: meal.id)
  end

  def self.total_for_meal(meal)
    where(meal_id: meal.id).sum(SIGNUP_TYPES.join("+"))
  end

  def self.totals_for_meal(meal)
    SIGNUP_TYPES.map { |st| [st, 0] }.to_h.tap do |totals|
      meal.signups.each do |signup|
        next if signup.marked_for_destruction?
        SIGNUP_TYPES.each do |st|
          totals[st] += signup[st]
        end
      end
    end
  end

  def self.portions_for_meal(meal, food_type)
    totals = totals_for_meal(meal)
    DINER_TYPES.map { |dt| totals["#{dt}_#{food_type}"] * PORTION_FACTORS[dt.to_sym] }.reduce(:+)
  end

  def self.all_zero_attribs?(attribs)
    attribs.slice(*SIGNUP_TYPES).values.map(&:to_i).uniq == [0]
  end

  def save_or_destroy
    all_zero? && persisted? ? destroy : save
  end

  def count_for(diner_type, food_type)
    self["#{diner_type}_#{food_type}"]
  end

  def total
    @total ||= SIGNUP_TYPES.sum { |t| send(t) || 0 }
  end

  def total_was
    SIGNUP_TYPES.sum { |t| send("#{t}_was") || 0 }
  end

  # The diff in the current total minus the total before the current update
  def total_change
    total - total_was
  end

  private

  def all_zero?
    SIGNUP_TYPES.all? { |t| self[t].zero? }
  end

  def max_signups_per_type
    SIGNUP_TYPES.each do |t|
      errors.add(t, "maximum of #{MAX_PEOPLE_PER_TYPE}") if send(t) > MAX_PEOPLE_PER_TYPE
    end
  end

  def dont_exceed_spots
    return unless !meal.finalized? && total_change > meal.spots_left
    errors.add(:base, :exceeded_spots, count: meal.spots_left + total_was)
  end

  def nonzero_signups_if_new
    errors.add(:base, "You must sign up at least one person") if new_record? && all_zero?
  end
end
