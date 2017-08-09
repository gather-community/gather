module Meals
  class Formula < ActiveRecord::Base
    include Deactivatable

    attr_accessor :signup_types # For validation error setting only

    MEAL_CALC_TYPES = %i(fixed share)
    PANTRY_CALC_TYPES = %i(fixed percent)

    acts_as_tenant(:cluster)

    belongs_to :community
    has_many :meals, inverse_of: :formula

    scope :for_community, ->(c) { where(community_id: c.id) }
    scope :newest_first, -> { order(created_at: :desc) }
    scope :with_meal_counts, -> { select("meal_formulas.*,
      (SELECT COUNT(id) FROM meals WHERE formula_id = meal_formulas.id) AS meal_count") }
    scope :deactivated_last, -> { order("COALESCE(deactivated_at, '0001-01-01 00:00:00')") }
    scope :by_name, -> { order("LOWER(name)") }

    validates :name, :meal_calc_type, :pantry_calc_type, :pantry_fee, presence: true
    validates :pantry_fee, numericality: {greater_than_or_equal_to: 0}
    validate :at_least_one_signup_type

    Signup::SIGNUP_TYPES.each do |st|
      validates st, numericality: {greater_than_or_equal_to: 0}, if: ->(f) { f[st].present? }
    end

    def self.newest_for(community)
      for_community(community).newest_first.first
    end

    def has_meals?
      meals.any?
    end

    def allowed_diner_types
      @allowed_diner_types ||= Signup::DINER_TYPES.select { |dt| allows_diner_type?(dt) }
    end

    def allowed_signup_types
      @allowed_signup_types ||= Signup::SIGNUP_TYPES.select { |st| allows_signup_type?(st) }
    end

    def allows_diner_type?(diner_type)
      Signup::SIGNUP_TYPES.any?{ |st| st =~ /\A#{diner_type}_/ && self[st].present? }
    end

    def allows_signup_type?(diner_type_or_both, meal_type = nil)
      attrib = meal_type.present? ? "#{diner_type_or_both}_#{meal_type}" : diner_type_or_both
      !self[attrib].nil?
    end

    def portion_factors
      allowed_diner_types.map{ |dt| [dt, Signup::PORTION_FACTORS[dt.to_sym]] }.to_h
    end

    def fixed_meal?
      meal_calc_type == "fixed"
    end

    def fixed_pantry?
      pantry_calc_type == "fixed"
    end

    def max_cost
      Signup::SIGNUP_TYPES.map { |st| self[st] }.compact.max
    end

    private

    def at_least_one_signup_type
      if fixed_meal?
        if Signup::SIGNUP_TYPES.all? { |st| self[st].blank? }
          errors.add(:signup_types, :at_least_one_signup_type)
        end
      else
        if Signup::SIGNUP_TYPES.all? { |st| self[st].blank? || self[st] == 0 }
          errors.add(:signup_types, :at_least_one_nonzero_signup_type)
        end
      end
    end
  end
end
