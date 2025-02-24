# frozen_string_literal: true

module Meals
  # Describes a meal system.
  class Formula < ApplicationRecord
    include Wisper.model
    include Deactivatable
    include SemicolonDisallowable

    MEAL_CALC_TYPES = %i[fixed share].freeze
    PANTRY_CALC_TYPES = %i[fixed percent].freeze

    acts_as_tenant :cluster

    belongs_to :community
    has_many :meals, class_name: "Meals::Meal", inverse_of: :formula
    has_many :formula_roles, inverse_of: :formula, dependent: :destroy
    has_many :roles, -> { by_title }, through: :formula_roles
    has_many :parts, -> { includes(:type).by_rank }, class_name: "Meals::FormulaPart", inverse_of: :formula,
                                                     dependent: :destroy
    has_many :types, through: :parts
    has_many :work_meal_job_sync_settings, class_name: "Work::MealJobSyncSetting", inverse_of: :formula,
                                           dependent: :destroy

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :newest_first, -> { order(created_at: :desc) }
    scope :with_meal_counts, lambda {
                               select("meal_formulas.*, (SELECT COUNT(id) FROM meals " \
                                      "WHERE formula_id = meal_formulas.id) AS meal_count")
                             }
    scope :by_name, -> { alpha_order(:name) }

    normalize_attribute :name

    validates :name, :meal_calc_type, :pantry_calc_type, :pantry_fee, presence: true
    validates :pantry_fee, numericality: {greater_than_or_equal_to: 0}
    validate :at_least_one_type
    validate :cant_unset_default
    validate :must_have_head_cook_role

    disallow_semicolons :name

    accepts_nested_attributes_for :parts, reject_if: :all_blank, allow_destroy: true

    after_save :ensure_unique_default

    def self.default_for(community)
      in_community(community).find_by(is_default: true)
    end

    def parts_by_type
      @parts_by_type ||= parts.index_by(&:type)
    end

    def types
      @types ||= parts.map(&:type)
    end

    def meals?
      meals.any?
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
