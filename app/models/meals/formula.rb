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
    scope :by_name, -> { order("LOWER(name)") }

    normalize_attribute :name

    validates :name, :meal_calc_type, :pantry_calc_type, :pantry_fee, presence: true
    validates :pantry_fee, numericality: {greater_than_or_equal_to: 0}
    validate :at_least_one_signup_type
    validate :cant_unset_default
    Signup::SIGNUP_TYPES.each do |st|
      validates st, numericality: {greater_than_or_equal_to: 0}, if: -> { self[st].present? }
    end

    after_save :ensure_unique_default

    def self.default_for(community)
      for_community(community).where(is_default: true).first
    end

    def defined_signup_types
      Signup::SIGNUP_TYPES.select { |st| self[st].present? }
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
      meal_calc_type.blank? || meal_calc_type == "fixed"
    end

    def fixed_pantry?
      pantry_calc_type.blank? || pantry_calc_type == "fixed"
    end

    def max_cost
      Signup::SIGNUP_TYPES.map { |st| self[st] }.compact.max
    end

    def pantry_fee_disp=(str)
      self.pantry_fee = normalize_amount(str, pct: !fixed_pantry?)
    end

    Signup::SIGNUP_TYPES.each do |st|
      define_method("#{st}_disp=") do |str|
        send("#{st}=", normalize_amount(str, pct: !fixed_meal?))
      end
    end

    private

    def cant_unset_default
      if is_default_changed? && is_default_was
        errors.add(:is_default, :cant_unset)
      end
    end

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

    def ensure_unique_default
      if is_default?
        self.class.for_community(community).where.not(id: id).update_all(is_default: false)
      end
    end

    def separator
      I18n.t("number.format.separator")
    end

    # Converts a string like "$2.11" or "82%" to 2.11 or 82, respectively. If pct is true, divides by 100.
    def normalize_amount(value, pct:)
      value = value.try(:gsub, /[^#{separator}0-9]/, "")
      return nil if value.blank?
      value.to_f / (pct ? 100 : 1)
    end
  end
end
