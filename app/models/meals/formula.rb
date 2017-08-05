module Meals
  class Formula < ActiveRecord::Base
    include Deactivatable

    acts_as_tenant(:cluster)

    belongs_to(:community)

    scope :for_community, ->(c) { where(community_id: c.id) }
    scope :newest_first, -> { order(created_at: :desc) }

    def allowed_diner_types
      @allowed_diner_types ||= Signup::DINER_TYPES.select{ |dt| allows_diner_type?(dt) }
    end

    def allowed_signup_types
      @allowed_signup_types ||= Signup::SIGNUP_TYPES.select{ |st| allows_signup_type?(st) }
    end

    def allows_diner_type?(diner_type)
      Signup::SIGNUP_TYPES.any?{ |st| st =~ /^#{diner_type}_/ && send("#{st}").present? }
    end

    def allows_signup_type?(diner_type_or_both, meal_type = nil)
      attrib = meal_type.present? ? "#{diner_type_or_both}_#{meal_type}" : diner_type_or_both
      !self[attrib].nil?
    end

    def portion_factors
      allowed_diner_types.map{ |dt| [dt, Signup::PORTION_FACTORS[dt.to_sym]] }.to_h
    end

    def fixed_pantry?
      pantry_calc_type == "fixed"
    end
  end
end
