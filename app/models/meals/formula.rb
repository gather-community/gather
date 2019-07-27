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
    has_many :parts, -> { includes(:type).by_rank }, class_name: "Meals::FormulaPart", inverse_of: :formula,
                                                     dependent: :destroy
    has_many :types, through: :parts

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
    validate :at_least_one_type
    validate :cant_unset_default
    validate :must_have_head_cook_role

    accepts_nested_attributes_for :parts, reject_if: :all_blank, allow_destroy: true

    # 73 TODO: Remove
    Signup::SIGNUP_TYPES.each do |st|
      validates st, numericality: {greater_than_or_equal_to: 0}, if: -> { self[st].present? }
    end

    after_save :ensure_unique_default
    after_update { RoleReminderMaintainer.instance.formula_saved(meals, roles) }

    def self.default_for(community)
      in_community(community).find_by(is_default: true)
    end

    def [](key)
      if key.is_a?(Meals::Type)
        parts_by_type[key].share
      else # 73 TODO: remove
        read_attribute(key)
      end
    end

    def parts_by_type
      @parts_by_type ||= parts.index_by(&:type)
    end

    def types
      @types ||= parts.map(&:type)
    end

    # 73 TODO: Remove
    def defined_signup_types
      Signup::SIGNUP_TYPES.select { |st| self[st].present? }
    end

    def meals?
      meals.any?
    end

    # 73 TODO: Remove
    def allowed_diner_types
      @allowed_diner_types ||= Signup::DINER_TYPES.select { |dt| allows_diner_type?(dt) }
    end

    # 73 TODO: Remove
    def allowed_signup_types
      @allowed_signup_types ||= Signup::SIGNUP_TYPES.select { |st| allows_signup_type?(st) }
    end

    # 73 TODO: Remove
    def allows_diner_type?(diner_type)
      Signup::SIGNUP_TYPES.any? { |st| st =~ /\A#{diner_type}_/ && self[st].present? }
    end

    # 73 TODO: Remove
    def allows_signup_type?(diner_type_or_both, meal_type = nil)
      attrib = meal_type.present? ? "#{diner_type_or_both}_#{meal_type}" : diner_type_or_both
      !self[attrib].nil?
    end

    # 73 TODO: Remove
    def portion_factors
      allowed_diner_types.map { |dt| [dt, Signup::PORTION_FACTORS[dt.to_sym]] }.to_h
    end

    def fixed_meal?
      meal_calc_type.blank? || meal_calc_type == "fixed"
    end

    def fixed_pantry?
      pantry_calc_type.blank? || pantry_calc_type == "fixed"
    end

    def pantry_fee_formatted=(str)
      self.pantry_fee = CurrencyPercentageNormalizer.normalize(str, pct: !fixed_pantry?)
    end

    def head_cook_role
      roles.detect(&:head_cook?)
    end

    private

    def cant_unset_default
      errors.add(:is_default, :cant_unset) if is_default_changed? && is_default_was
    end

    def at_least_one_type
      if fixed_meal?
        errors.add(:parts, :at_least_one_type) if parts.reject(&:marked_for_destruction?).empty?
      elsif parts.reject(&:marked_for_destruction?).none?(&:nonzero?)
        errors.add(:parts, :at_least_one_nonzero_type)
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
  end
end
