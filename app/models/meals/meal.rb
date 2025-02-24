# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meals
#
#  id              :integer          not null, primary key
#  allergens       :jsonb            not null
#  auto_close_time :datetime
#  capacity        :integer          not null
#  dessert         :text
#  entrees         :text
#  kids            :text
#  menu_posted_at  :datetime
#  no_allergens    :boolean          default(FALSE), not null
#  notes           :text
#  served_at       :datetime         not null
#  side            :text
#  status          :string           default("open"), not null
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  cluster_id      :integer          not null
#  community_id    :integer          not null
#  creator_id      :integer          not null
#  formula_id      :integer          not null
#
# Indexes
#
#  index_meals_on_cluster_id  (cluster_id)
#  index_meals_on_creator_id  (creator_id)
#  index_meals_on_formula_id  (formula_id)
#  index_meals_on_served_at   (served_at)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (formula_id => meal_formulas.id)
#
  # Models a common meal.
  class Meal < ApplicationRecord
    self.table_name = "meals" # Override suffix

    include Wisper.model
    include TimeCalculable
    include Statusable

    DEFAULT_TIME = 18.hours + 15.minutes
    DEFAULT_CAPACITY = 64
    ALLERGENS = %w[gluten shellfish soy corn dairy eggs peanuts almonds
      tree_nuts pineapple bananas tofu eggplant].freeze
    DEFAULT_ASSIGN_COUNTS = {asst_cook: 2, table_setter: 1, cleaner: 3}.freeze
    MENU_ITEMS = %w[entrees side kids dessert notes].freeze

    acts_as_tenant :cluster

    attr_accessor :source_form # Which form is submitting data to the model.

    belongs_to :community, class_name: "Community"
    belongs_to :creator, class_name: "User"
    belongs_to :formula, class_name: "Meals::Formula", inverse_of: :meals
    has_many :assignments, -> { by_role }, class_name: "Meals::Assignment",
      dependent: :destroy, inverse_of: :meal
    has_many :invitations, class_name: "Meals::Invitation", dependent: :destroy
    has_many :communities, through: :invitations
    has_many :signups, class_name: "Meals::Signup", dependent: :destroy, inverse_of: :meal
    has_many :work_shifts, class_name: "Work::Shift", dependent: :destroy, inverse_of: :meal
    has_one :cost, class_name: "Meals::Cost", dependent: :destroy, inverse_of: :meal
    has_many :reminder_deliveries, class_name: "Meals::RoleReminderDelivery", inverse_of: :meal,
      dependent: :destroy
    has_many :transactions, class_name: "Billing::Transaction", as: :statementable,
      dependent: :restrict_with_exception, inverse_of: :statementable

    # Calendars are chosen by the user. Events are then automatically created.
    # Deterministic orderings are for specs.
    has_many :resourcings, dependent: :destroy
    has_many :calendars, -> { order(:id) }, class_name: "Calendars::Calendar", through: :resourcings
    has_many :events, -> { order(:id) }, class_name: "Calendars::Event", autosave: true,
      dependent: :destroy, inverse_of: :meal

    scope :hosted_by, ->(community) { where(community: community) }
    scope :inviting, ->(community) {
      where("EXISTS (SELECT id FROM meal_invitations
        WHERE meal_invitations.meal_id = meals.id AND meal_invitations.community_id = ?)", community)
    }
    scope :oldest_first, -> { order(served_at: :asc).by_community.order(:id) }
    scope :newest_first, -> { order(served_at: :desc).by_community_reverse.order(id: :desc) }
    scope :in_community, ->(c) { where(community: c) }
    scope :by_community, -> { joins(:community).alpha_order(communities: :name) }
    scope :by_community_reverse, -> { joins(:community).alpha_order("communities.name": :desc) }
    scope :without_menu, -> { where(MENU_ITEMS.map { |i| "#{i} IS NULL" }.join(" AND ")) }
    scope :with_min_age, ->(age) { where("served_at <= ?", Time.current - age) }
    scope :with_max_age, ->(age) { where("served_at >= ?", Time.current - age) }
    scope :in_time_range, ->(r) { where("served_at <= ?", r.last).where("served_at >= ?", r.first) }
    scope :with_past_auto_close_time, -> { where("auto_close_time < ?", Time.current) }
    scope :worked_by, lambda { |user, head_cook_only: false|
      user = user.id if user.is_a?(User)
      assignments = Meals::Assignment.arel_table
      meals = arel_table
      rel = Meals::Assignment.select(:user_id).where(assignments[:meal_id].eq(meals[:id]))
      rel = rel.joins(:role).merge(Meals::Role.head_cook) if head_cook_only
      where("? IN (#{rel.to_sql})", user)
    }
    scope :attended_by, ->(household) { joins(:signups).where(meal_signups: {household_id: household.id}) }

    accepts_nested_attributes_for :signups, allow_destroy: true, reject_if: lambda { |a|
      a["id"].blank? && a["parts_attributes"].values.all? { |v| v["count"] == "0" }
    }
    accepts_nested_attributes_for :cost,
      reject_if: ->(a) { a.all? { |k, v| k == "reimbursee_id" || v.blank? } }
    accepts_nested_attributes_for :assignments, reject_if: ->(h) { h["user_id"].blank? }, allow_destroy: true

    delegate :cluster, to: :community
    delegate :name, to: :community, prefix: true
    delegate :name, to: :head_cook, prefix: true, allow_nil: true
    delegate :name, to: :formula, prefix: true, allow_nil: true
    delegate :head_cook_role, :types, to: :formula
    delegate :build_events, to: :event_handler

    before_save :set_menu_timestamp

    normalize_attributes :title, :entrees, :side, :kids, :dessert, :notes, :capacity

    with_options if: :main_form_or_import? do
      validates :creator_id, presence: true
      validates :formula_id, presence: true
      validates :served_at, presence: true
      validates :community_id, presence: true
      validates :capacity, presence: true, numericality: {greater_than: 0, less_than: 500}
      validate :enough_capacity_for_current_signups
      validate :auto_close_between_now_and_meal_time
      validate :title_and_entree_if_other_menu_items
      validate :at_least_one_community
      validate :allergens_specified_appropriately
      validate { event_handler.validate_meal if events.any? }
      validates_with Meals::SignupsValidator
    end

    def self.served_within_days_from_now(days)
      within_days_from_now(:served_at, days)
    end

    def roles
      formula&.roles || []
    end

    def head_cook
      assignments.detect(&:head_cook?)&.user
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

    def auto_close_time_in_past?
      auto_close_time.present? && auto_close_time < Time.current
    end

    def event_handler
      @event_handler ||= Meals::EventHandler.new(self)
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
      # The signups collection may contain a new_record? signup that shouldn't count
      # toward the total.
      signups.select(&:persisted?).sum(&:total)
    end

    def spots_left
      [capacity - signup_count, 0].max
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

    def auto_close_between_now_and_meal_time
      return unless open?
      return if auto_close_time.blank? || served_at.blank?
      return if auto_close_time > Time.current && auto_close_time < served_at
      errors.add(:auto_close_time, "must be between now and the meal time")
    end

    def allergens_specified_appropriately
      return unless menu_posted?
      if !allergens? && !no_allergens?
        errors.add(:allergens, "at least one box must be checked if menu entered")
      elsif allergens? && no_allergens?
        errors.add(:allergens, "'None' can't be selected if other allergens present")
      end
    end

    def set_menu_timestamp
      self.menu_posted_at = Time.current if menu_posted? && title_was.blank?
    end

    def main_form_or_import?
      %w[main import].include?(source_form)
    end
  end
end
