# frozen_string_literal: true

module Meals
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

    attr_accessor :signup # Dummy used only in form construction.

    has_many :parts, -> { includes(:type).by_rank },
      class_name: "Meals::SignupPart", inverse_of: :signup, dependent: :destroy
    belongs_to :meal, class_name: "Meals::Meal", inverse_of: :signups
    belongs_to :household

    scope :community_first, lambda { |c|
      includes(household: :community).order("CASE WHEN communities.id = #{c.id} THEN 0 ELSE 1 END")
    }
    scope :sorted, -> { joins(household: :community).order("communities.abbrv, households.name") }

    normalize_attributes :comments

    after_update :destroy_if_all_zero

    validates :household_id, presence: true, uniqueness: {scope: :meal_id}
    validates :comments, length: {maximum: MAX_COMMENT_LENGTH}
    validate :max_signups_per_type
    validate :dont_exceed_spots
    validate :nonzero_signups_if_new
    validate :no_dupe_types

    delegate :name, :users, :adults, to: :household, prefix: true
    delegate :community_abbrv, to: :household
    delegate :communities, :formula, :types, to: :meal

    accepts_nested_attributes_for :parts, reject_if: :all_blank, allow_destroy: true

    def self.for(user, meal)
      find_or_initialize_by(household_id: user.household_id, meal_id: meal.id) do |signup|
        # For new signup, build parts similar to the most recently used for the given household/formula pair.
        recent = joins(:meal).where(household: user.household).includes(parts: :type)
          .where(meals: {formula_id: meal.formula_id}).order(created_at: :desc).first
        if recent
          recent.parts.map { |p| signup.parts.build(type: p.type, count: p.count) }
        else
          signup.init_default
        end
      end
    end

    # 73 TODO: Remove
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

    # Sets some default part data.
    def init_default
      parts.build(type: meal.types[0], count: 1)
    end

    def total
      parts.reject(&:marked_for_destruction?).sum(&:count)
    end

    def total_was
      parts.map(&:count_was).compact.sum # Deliberately including those marked_for_destruction
    end

    def parts_by_type
      @parts_by_type ||= parts.index_by(&:type)
    end

    private

    def all_zero?
      parts.all?(&:zero?)
    end

    def max_signups_per_type
      SIGNUP_TYPES.each do |t|
        errors.add(t, "maximum of #{MAX_PEOPLE_PER_TYPE}") if send(t) > MAX_PEOPLE_PER_TYPE
      end
    end

    def dont_exceed_spots
      total_change = total - total_was
      return unless !meal.finalized? && meal.capacity.present? && total_change.positive?
      other_signups_total = (meal.signups - [self]).sum(&:total)
      return if other_signups_total + total <= meal.capacity
      max_spots_can_take = [meal.capacity - other_signups_total, total_was].max
      errors.add(:base, :exceeded_spots, count: max_spots_can_take)
    end

    def nonzero_signups_if_new
      errors.add(:base, "You must sign up at least one person") if new_record? && all_zero?
    end

    def no_dupe_types
      type_ids = parts.map(&:type_id)
      return if type_ids.uniq.size == type_ids.size
      errors.add(:base, "Please sign up each type only once")
    end

    def destroy_if_all_zero
      destroy if all_zero?
    end
  end
end
