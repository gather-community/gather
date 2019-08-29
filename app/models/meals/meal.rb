# frozen_string_literal: true

module Meals
  # Models a common meal.
  class Meal < ApplicationRecord
    self.table_name = "meals" # Override suffix

    include TimeCalculable

    DEFAULT_TIME = 18.hours + 15.minutes
    DEFAULT_CAPACITY = 64
    ALLERGENS = %w[gluten shellfish soy corn dairy eggs peanuts almonds
                   tree_nuts pineapple bananas tofu eggplant].freeze
    DEFAULT_ASSIGN_COUNTS = {asst_cook: 2, table_setter: 1, cleaner: 3}.freeze
    MENU_ITEMS = %w[entrees side kids dessert notes].freeze

    acts_as_tenant :cluster

    belongs_to :community, class_name: "Community"
    belongs_to :creator, class_name: "User"
    belongs_to :formula, class_name: "Meals::Formula", inverse_of: :meals
    has_many :assignments, -> { by_role }, class_name: "Meals::Assignment",
                                           dependent: :destroy, inverse_of: :meal
    has_many :invitations, class_name: "Meals::Invitation", dependent: :destroy
    has_many :communities, through: :invitations
    has_many :signups, -> { sorted }, class_name: "Meals::Signup", dependent: :destroy, inverse_of: :meal
    has_many :work_shifts, class_name: "Work::Shift", dependent: :destroy, inverse_of: :meal
    has_one :cost, class_name: "Meals::Cost", dependent: :destroy, inverse_of: :meal
    has_many :reminder_deliveries, class_name: "Meals::RoleReminderDelivery", inverse_of: :meal,
                                   dependent: :destroy

    # Resources are chosen by the user. Reservations are then automatically created.
    # Deterministic orderings are for specs.
    has_many :resourcings, class_name: "Reservations::Resourcing", dependent: :destroy
    has_many :resources, -> { order(:id) }, class_name: "Reservations::Resource", through: :resourcings
    has_many :reservations, -> { order(:id) }, class_name: "Reservations::Reservation", autosave: true,
                                               dependent: :destroy, inverse_of: :meal

    scope :hosted_by, ->(community) { where(community: community) }
    scope :oldest_first, -> { order(served_at: :asc).by_community.order(:id) }
    scope :newest_first, -> { order(served_at: :desc).by_community_reverse.order(id: :desc) }
    scope :by_community, -> { joins(:community).alpha_order(communities: :name) }
    scope :by_community_reverse, -> { joins(:community).alpha_order("communities.name": :desc) }
    scope :without_menu, -> { where(MENU_ITEMS.map { |i| "#{i} IS NULL" }.join(" AND ")) }
    scope :with_min_age, ->(age) { where("served_at <= ?", Time.current - age) }
    scope :with_max_age, ->(age) { where("served_at >= ?", Time.current - age) }
    scope :worked_by, lambda { |user, head_cook_only: false|
      user = user.id if user.is_a?(User)
      assignments = Meals::Assignment.arel_table
      meals = arel_table
      rel = Meals::Assignment.select(:user_id).where(assignments[:meal_id].eq(meals[:id]))
      rel = rel.joins(:role).merge(Meals::Role.head_cook) if head_cook_only
      where("? IN (#{rel.to_sql})", user)
    }
    scope :attended_by, ->(household) { includes(:signups).where(meal_signups: {household_id: household.id}) }

    Meals::Status.define_scopes(self)

    accepts_nested_attributes_for :signups, allow_destroy: true, reject_if: lambda { |a|
      a["id"].blank? && a["parts_attributes"].values.all? { |v| v["count"] == "0" }
    }
    accepts_nested_attributes_for :cost, reject_if: :all_blank
    accepts_nested_attributes_for :assignments, reject_if: ->(h) { h["user_id"].blank? }, allow_destroy: true

    delegate :cluster, to: :community
    delegate :name, to: :community, prefix: true
    delegate :name, to: :head_cook, prefix: true, allow_nil: true
    delegate :name, to: :formula, prefix: true, allow_nil: true
    delegate :head_cook_role, :types, to: :formula
    delegate :build_reservations, to: :reservation_handler
    delegate :close!, :reopen!, :cancel!, :finalize!,
      :closed?, :finalized?, :open?, :cancelled?,
      :full?, :in_past?, :day_in_past?, to: :status_obj

    after_validation :copy_resource_errors
    before_save :set_menu_timestamp
    after_save do
      if saved_change_to_served_at?
        Meals::RoleReminderMaintainer.instance.meal_saved(roles, reminder_deliveries)
      end
    end

    normalize_attributes :title, :entrees, :side, :kids, :dessert, :notes, :capacity

    validates :creator_id, presence: true
    validates :formula_id, presence: true
    validates :served_at, presence: true
    validates :community_id, presence: true
    validates :capacity, presence: true, numericality: {greater_than: 0, less_than: 500}
    validate :enough_capacity_for_current_signups
    validate :title_and_entree_if_other_menu_items
    validate :at_least_one_community
    validate :allergens_specified_appropriately
    validate { reservation_handler.validate_meal if reservations.any? }
    validates :resources, presence: {message: :need_location}
    validates_with Meals::SignupsValidator

    def self.served_within_days_from_now(days)
      within_days_from_now(:served_at, days)
    end

    def roles
      formula&.roles || []
    end

    def head_cook
      assignments.detect(&:head_cook?)&.user
    end

    def status_obj
      @status_obj ||= Meals::Status.new(self)
    end

    def workers
      @workers ||= assignments.map(&:user).uniq
    end

    def assignments_by_role
      @assignments_by_role ||= assignments.group_by(&:role)
    end

    def community_ids
      invitations.map(&:community_id)
    end

    def community_invited?(community)
      community_ids.include?(community.id)
    end

    # Duck type for calendaring.
    def starts_at
      served_at
    end

    def ends_at
      served_at + 1.hour
    end

    def reservation_handler
      @reservation_handler ||= Reservations::MealReservationHandler.new(self)
    end

    # Accepts values from the community checkboxes on the form.
    # Hash is of form { <community_id> => "1", ... }
    def community_boxes=(hash)
      new_ids = hash.keys.map(&:to_i)
      existing_ids = community_ids

      to_create = new_ids - existing_ids
      to_delete = existing_ids - new_ids

      to_create.each { |id| invitations.build(community_id: id) }

      invitations.each do |inv|
        if to_delete.include?(inv.community_id)
          inv.destroy if inv.persisted?
          invitations.delete(inv)
        end
      end
    end

    def signup_count
      signups.sum(&:total)
    end

    def signup_totals
      @signup_totals = formula.parts.map { |p| [p.type, 0] }.to_h.tap do |totals|
        signups.each do |signup|
          next if signup.marked_for_destruction?
          formula.parts.each do |part|
            totals[part.type] += signup.parts_by_type[part.type]&.count || 0
          end
        end
      end
    end

    def spots_left
      @spots_left ||= [capacity - signup_count, 0].max
    end

    def menu_posted?
      allergens? || title? || MENU_ITEMS.any? { |a| self[a].present? }
    end

    # Returns a relation for all meals following the current one.
    # We break ties using community name and then ID.
    def following_meals
      self.class.joins(:community)
        .where("served_at > ? OR served_at = ? AND
          (communities.name > ? OR communities.name = ? AND meals.id > ?)",
          served_at, served_at, community_name, community_name, id)
    end

    # Returns a relation for all meals before the current one.
    # We break ties using community name and then ID.
    def previous_meals
      self.class.joins(:community)
        .where("served_at < ? OR served_at = ? AND
          (communities.name < ? OR communities.name = ? AND meals.id < ?)",
          served_at, served_at, community_name, community_name, id)
    end

    def allergen?(allergen)
      allergens.include?(allergen)
    end

    private

    def enough_capacity_for_current_signups
      return unless persisted? && !finalized? && capacity && capacity < signup_count
      errors.add(:capacity, "must be at least #{signup_count} due to current signups")
    end

    def title_and_entree_if_other_menu_items
      %w[title entrees].each do |attrib|
        next unless self[attrib].blank? && menu_posted?
        errors.add(attrib, "can't be blank if other menu items entered")
      end
    end

    def at_least_one_community
      return unless invitations.reject(&:blank?).empty?
      errors.add(:invitations, "you must invite at least one community")
    end

    def allergens_specified_appropriately
      return unless menu_posted?
      if !allergens? && !no_allergens?
        errors.add(:allergens, "at least one box must be checked if menu entered")
      elsif allergens? && no_allergens?
        errors.add(:allergens, "'None' can't be selected if other allergens present")
      end
    end

    def copy_resource_errors
      errors[:resources].each { |m| errors.add(:resource_ids, m) }
    end

    def set_menu_timestamp
      self.menu_posted_at = Time.current if menu_posted? && title_was.blank?
    end
  end
end
