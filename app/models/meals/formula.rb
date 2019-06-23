# frozen_string_literal: true

module Meals
  # Describes a meal system.
  class Formula < ApplicationRecord
    include Deactivatable

    attr_accessor :signup_types # For validation error setting only

    MEAL_CALC_TYPES = %i[fixed share].freeze
    PANTRY_CALC_TYPES = %i[fixed percent].freeze

    acts_as_tenant :cluster

    belongs_to :community
    has_many :meals, inverse_of: :formula
    has_many :formula_roles, inverse_of: :formula, dependent: :destroy
    has_many :roles, -> { by_title }, through: :formula_roles
    has_many :parts, class_name: "Meals::FormulaPart", inverse_of: :formula, dependent: :destroy

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :newest_first, -> { order(created_at: :desc) }
    scope :with_meal_counts, lambda {
                               select("meal_formulas.*, (SELECT COUNT(id) FROM meals "\
                                 "WHERE formula_id = meal_formulas.id) AS meal_count")
                             }
    scope :by_name, -> { alpha_order(:name) }

    normalize_attribute :name

    validates :name, :meal_calc_type, :pantry_calc_type, :pantry_fee, presence: true
    validates :pantry_fee, numericality: {greater_than_or_equal_to: 0}
    validate :at_least_one_signup_type
    validate :cant_unset_default
    validate :must_have_head_cook_role
    Signup::SIGNUP_TYPES.each do |st|
      validates st, numericality: {greater_than_or_equal_to: 0}, if: -> { self[st].present? }
    end

    after_save :ensure_unique_default
    after_update { RoleReminderMaintainer.instance.formula_saved(meals, roles) }

    def self.default_for(community)
      in_community(community).find_by(is_default: true)
    end

    def item_id_options
      defined_signup_types.map { |t| [I18n.t("signups.types.#{t}"), t] }
    end

    def defined_signup_types
      Signup::SIGNUP_TYPES.select { |st| self[st].present? }
    end

    def meals?
      meals.any?
    end

    def allowed_diner_types
      @allowed_diner_types ||= Signup::DINER_TYPES.select { |dt| allows_diner_type?(dt) }
    end

    def allowed_signup_types
      @allowed_signup_types ||= Signup::SIGNUP_TYPES.select { |st| allows_signup_type?(st) }
    end

    def allows_diner_type?(diner_type)
      Signup::SIGNUP_TYPES.any? { |st| st =~ /\A#{diner_type}_/ && self[st].present? }
    end

    def allows_signup_type?(diner_type_or_both, meal_type = nil)
      attrib = meal_type.present? ? "#{diner_type_or_both}_#{meal_type}" : diner_type_or_both
      !self[attrib].nil?
    end

    def portion_factors
      allowed_diner_types.map { |dt| [dt, Signup::PORTION_FACTORS[dt.to_sym]] }.to_h
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

    def pantry_fee_nice=(str)
      self.pantry_fee = normalize_amount(str, pct: !fixed_pantry?)
    end

    Signup::SIGNUP_TYPES.each do |st|
      define_method("#{st}_nice=") do |str|
        send("#{st}=", normalize_amount(str, pct: !fixed_meal?))
      end
    end

    def head_cook_role
      roles.detect(&:head_cook?)
    end

    private

    def cant_unset_default
      errors.add(:is_default, :cant_unset) if is_default_changed? && is_default_was
    end

    def at_least_one_signup_type
      if fixed_meal?
        if Signup::SIGNUP_TYPES.all? { |st| self[st].blank? }
          errors.add(:signup_types, :at_least_one_signup_type)
        end
      elsif Signup::SIGNUP_TYPES.all? { |st| self[st].blank? || self[st].zero? }
        errors.add(:signup_types, :at_least_one_nonzero_signup_type)
      end
    end

    def must_have_head_cook_role
      head_cook_role = Meals::Role.in_community(community).head_cook.first
      return if head_cook_role.nil? || role_ids.include?(head_cook_role.id)
      errors.add(:role_ids, :must_have_head_cook, title: head_cook_role.title)
    end

    def ensure_unique_default
      self.class.in_community(community).where.not(id: id).update_all(is_default: false) if is_default?
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
