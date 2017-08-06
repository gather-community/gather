module Meals
  class Formula < ActiveRecord::Base
    include Deactivatable

    acts_as_tenant(:cluster)

    belongs_to :community
    has_many :meals, inverse_of: :formula

    scope :for_community, ->(c) { where(community_id: c.id) }
    scope :newest_first, -> { order(created_at: :desc) }
    scope :with_meal_counts, -> { select("meal_formulas.*,
      (SELECT COUNT(id) FROM meals WHERE formula_id = meal_formulas.id) AS meal_count") }

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
  end
end
