# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_signups
#
#  id           :integer          not null, primary key
#  comments     :text
#  notified     :boolean          default(FALSE), not null
#  takeout      :boolean          default(FALSE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :integer          not null
#  household_id :integer          not null
#  meal_id      :integer          not null
#
# Indexes
#
#  index_meal_signups_on_cluster_id                (cluster_id)
#  index_meal_signups_on_household_id              (household_id)
#  index_meal_signups_on_household_id_and_meal_id  (household_id,meal_id) UNIQUE
#  index_meal_signups_on_meal_id                   (meal_id)
#  index_meal_signups_on_notified                  (notified)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (household_id => households.id)
#  fk_rails_...  (meal_id => meals.id)
#
  # Models information about one household's attendance at a meal.
  class Signup < ApplicationRecord
    MAX_COMMENT_LENGTH = 500

    acts_as_tenant :cluster

    attr_accessor :signup # Dummy used only in form construction.

    has_many :parts, -> { includes(:type).by_rank },
             class_name: "Meals::SignupPart", inverse_of: :signup, dependent: :destroy
    belongs_to :meal, class_name: "Meals::Meal", inverse_of: :signups
    belongs_to :household

    scope :by_one_cmty_first, lambda { |c|
      joins(household: :community).order(Community.arel_table[:id].not_eq(c.id))
    }
    scope :sorted, -> { joins(household: :community).order("communities.abbrv, households.name") }

    normalize_attributes :comments

    before_save :remove_zero_parts
    after_update :destroy_if_all_zero

    validates :household_id, presence: true, uniqueness: {scope: :meal_id}
    validates :comments, length: {maximum: MAX_COMMENT_LENGTH}
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
        recent = unscoped.joins(:meal).where(household: user.household).includes(parts: :type)
          .where(meals: {formula_id: meal.formula_id}).order(created_at: :desc).first
        if recent
          recent.parts.map { |p| signup.parts.build(type: p.type, count: p.count) }
        else
          signup.init_default
        end
      end
    end

    # Sets some default part data.
    def init_default
      parts.build(type: meal.types[0], count: 1)
    end

    def total
      non_zero_non_destroyed_parts.sum(&:count)
    end

    def total_was
      parts.map(&:count_was).compact.sum # Deliberately including those marked_for_destruction
    end

    def parts_by_type
      @parts_by_type ||= parts.index_by(&:type)
    end

    private

    def non_zero_non_destroyed_parts
      parts.reject { |p| p.marked_for_destruction? || p.zero? }
    end

    def remove_zero_parts
      parts.each { |p| p.mark_for_destruction if p.zero? }
    end

    def all_zero?
      parts.all?(&:zero?)
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
      type_ids = non_zero_non_destroyed_parts.map(&:type_id)
      return if type_ids.uniq.size == type_ids.size
      errors.add(:base, "Please sign up each type only once")
    end

    def destroy_if_all_zero
      destroy if all_zero?
    end
  end
end
