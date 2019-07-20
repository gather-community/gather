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

    attr_accessor :flag_zzz

    acts_as_tenant :cluster

    attr_accessor :signup # Dummy used only in form construction.

    has_many :parts, class_name: "Meals::SignupPart", inverse_of: :signup, dependent: :destroy
    belongs_to :meal, class_name: "Meals::Meal", inverse_of: :signups
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
    delegate :communities, :formula, to: :meal

    accepts_nested_attributes_for :parts, reject_if: :all_blank, allow_destroy: true

    def self.for(user, meal)
      find_or_initialize_by(household_id: user.household_id, meal_id: meal.id) do |new_signup|
        lines = default_lines_for(household: user.household, formula: meal.formula)
        # Eventually we'll be able to just assign `lines` directly.
        new_signup.lines_attributes =
          lines.each_with_index.map { |l, i| [i, {item_id: l.item_id, quantity: l.quantity}] }.to_h
      end
    end

    # Gets the most recently used or generically default lines for the given household/formula pair.
    def self.default_lines_for(household:, formula:)
      if (recent = joins(:meal).where(household: household)
          .where(meals: {formula_id: formula.id}).order(created_at: :desc).first)
        recent.lines
      else
        [Meals::Line.new(quantity: 1, item_id: formula.defined_signup_types.first)]
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

    def save_or_destroy
      all_zero? && persisted? ? destroy : save
    end

    def count_for(diner_type, food_type)
      self["#{diner_type}_#{food_type}"]
    end

    def total
      if flag_zzz
        parts.reject(&:marked_for_destruction?).sum(&:count)
      else
        SIGNUP_TYPES.sum { |t| send(t) || 0 }
      end
    end

    def total_was
      if flag_zzz
        parts.map(&:count_was).compact.sum # Deliberately including those marked_for_destruction
      else
        SIGNUP_TYPES.sum { |t| send("#{t}_was") || 0 }
      end
    end

    # Will eventually be an AR association.
    def lines
      @lines ||= SIGNUP_TYPES.map do |t|
        # To mimic real association behavior, instantiate one Line with fake ID for each of the persisted
        # diner counts, plus one Line with no ID for any newly added ones.
        next unless self[t].positive?
        id = send("#{t}_was").zero? ? nil : rand(100_000_000)
        Meals::Line.new(id: id, item_id: t, quantity: self[t])
      end.compact
    end

    def build_line
      Meals::Line.new
    end

    # This will eventually be a nested attributes method.
    def lines_attributes=(attrib_sets)
      SIGNUP_TYPES.each { |t| send("#{t}=", 0) }
      attrib_sets.values.map do |set|
        next if set[:quantity].to_i.zero?
        send("#{set[:item_id]}=", send(set[:item_id]) + set[:quantity].to_i)
      end
      @lines = SIGNUP_TYPES.map do |t|
        next if send(t).zero?
        Meals::Line.new(item_id: t, quantity: send(t))
      end.compact
      attrib_sets.values.each do |set|
        next unless set[:quantity].to_i.zero?
        # Need to create these explicitly or they won't be preserved if the form is re-rendered.
        @lines << Meals::Line.new(item_id: set[:item_id], quantity: 0)
      end
    end

    private

    def all_zero?
      if flag_zzz
        parts.all?(&:zero?)
      else
        SIGNUP_TYPES.all? { |t| self[t].zero? }
      end
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
  end
end
