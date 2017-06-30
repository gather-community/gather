class Meal < ActiveRecord::Base
  include Statusable, TimeCalculable

  DEFAULT_TIME = 18.hours + 15.minutes
  DEFAULT_CAPACITY = 64
  ALLERGENS = %w(gluten shellfish soy corn dairy eggs peanuts almonds
    tree_nuts pineapple bananas tofu eggplant none)
  DEFAULT_ASSIGN_COUNTS = {asst_cook: 2, table_setter: 1, cleaner: 3}
  MENU_ITEMS = %w(entrees side kids dessert notes)
  PAYMENT_METHODS = %w(check credit)
  ALL_EXTRA_ROLES = %i(asst_cook table_setter cleaner)

  acts_as_tenant(:cluster)

  serialize :allergens, JSON

  belongs_to :community, class_name: "Community"
  belongs_to :creator, class_name: "User"
  has_many :assignments, dependent: :destroy
  has_one :head_cook_assign, ->{ where(role: "head_cook") }, class_name: "Assignment"
  has_many :asst_cook_assigns, ->{ where(role: "asst_cook") }, class_name: "Assignment"
  has_many :table_setter_assigns, ->{ where(role: "table_setter") }, class_name: "Assignment"
  has_many :cleaner_assigns, ->{ where(role: "cleaner") }, class_name: "Assignment"
  has_one :head_cook, through: :head_cook_assign, source: :user
  has_many :asst_cooks, through: :asst_cook_assigns, source: :user
  has_many :table_setters, through: :table_setter_assigns, source: :user
  has_many :cleaners, through: :cleaner_assigns, source: :user
  has_many :invitations, dependent: :destroy
  has_many :communities, through: :invitations
  has_many :signups, ->{ sorted }, dependent: :destroy, inverse_of: :meal
  has_one :cost, class_name: "Meals::Cost", dependent: :destroy, inverse_of: :meal

  # Resources are chosen by the user. Reservations are then automatically created.
  has_many :resourcings, class_name: "Reservation::Resourcing", dependent: :destroy
  has_many :resources, class_name: "Reservation::Resource", through: :resourcings
  has_many :reservations, class_name: "Reservation::Reservation", autosave: true, dependent: :destroy

  scope :open, -> { where(status: "open") }
  scope :hosted_by, ->(community) { where(community: community) }
  scope :finalizable, -> { past.where("status != ?", "finalized") }
  scope :oldest_first, -> { order(served_at: :asc).by_community.order(:id) }
  scope :newest_first, -> { order(served_at: :desc).by_community_reverse.order(id: :desc) }
  scope :by_community, -> { joins(:community).order("communities.name") }
  scope :by_community_reverse, -> { joins(:community).order("communities.name DESC") }
  scope :without_menu, -> { where(MENU_ITEMS.map{ |i| "#{i} IS NULL" }.join(" AND ")) }
  scope :past, -> { where("served_at <= ?", Time.current.midnight) }
  scope :future, -> { where("served_at >= ?", Time.current.midnight) }
  scope :with_min_age, ->(age) { where("served_at <= ?", Time.current - age) }
  scope :with_max_age, ->(age) { where("served_at >= ?", Time.current - age) }
  scope :worked_by, ->(user) { includes(:assignments).where(assignments: {user: user}) }
  scope :head_cooked_by, ->(user) { worked_by(user).where(assignments: {role: "head_cook"}) }
  scope :attended_by, ->(household) { includes(:signups).where(signups: {household_id: household.id}) }

  accepts_nested_attributes_for :head_cook_assign, reject_if: :all_blank
  accepts_nested_attributes_for :asst_cook_assigns, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :table_setter_assigns, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :cleaner_assigns, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :signups, allow_destroy: true
  accepts_nested_attributes_for :cost

  delegate :cluster, to: :community
  delegate :name, to: :community, prefix: true
  delegate :name, to: :head_cook, prefix: true
  delegate :allowed_diner_types, :allowed_signup_types, :portion_factors, to: :formula
  delegate :build_reservations, to: :reservation_handler

  before_validation do
    # Ensure head cook, even if blank, so we can add error to it.
    build_head_cook_assign if head_cook_assign.blank?
  end

  after_validation do
    errors[:resources].each { |m| errors.add(:resource_ids, m) }
  end

  normalize_attributes :title, :entrees, :side, :kids, :dessert, :notes, :capacity

  validates :creator_id, presence: true
  validates :served_at, presence: true
  validates :community_id, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0, less_than: 500 }
  validate :enough_capacity_for_current_signups
  validate :title_and_entree_if_other_menu_items
  validate :at_least_one_community
  validate :head_cook_presence
  validate :no_double_assignments
  validate :allergens_some_or_none_if_menu
  validate :allergen_none_alone
  validates :cost, presence: true, if: :finalized?
  validate { reservation_handler.validate_meal if reservations.any? }
  validates :resources, presence: { message: :need_location }

  def self.new_with_defaults(community)
    new(served_at: default_datetime,
      capacity: DEFAULT_CAPACITY,
      community_ids: Community.all.map(&:id),
      community: community)
  end

  def self.default_datetime
    Time.current.midnight + 7.days + Meal::DEFAULT_TIME
  end

  def self.served_within_days_from_now(days)
    within_days_from_now(:served_at, days)
  end

  def extra_roles
    @extra_roles ||= ALL_EXTRA_ROLES &
      (community.settings.meals.extra_roles || "").split(/\s*,\s*/).map(&:to_sym)
  end

  def people_in_role(role)
    raise ArgumentError("Invalid role #{role}") unless ALL_EXTRA_ROLES.include?(role)
    send("#{role.to_s.pluralize}")
  end

  def workers
    @workers ||= assignments.map(&:user).uniq
  end

  # Ensures there is one head_cook assignment and 2 each of the others.
  # Creates blank ones if needed.
  def ensure_assignments
    build_head_cook_assign if head_cook_assign.nil?
    extra_roles.each do |role|
      collection = send("#{role}_assigns")
      (DEFAULT_ASSIGN_COUNTS[role] - collection.size).times { collection.build }
    end
  end

  def title_or_no_title
    title || "[No Title]"
  end

  def community_ids
    invitations.map(&:community_id)
  end

  # Duck type for calendaring.
  def starts_at
    served_at
  end

  def ends_at
    served_at + 1.hour
  end

  def reservation_handler
    @reservation_handler ||= Reservation::MealReservationHandler.new(self)
  end

  # Accepts values from the community checkboxes on the form.
  # Hash is of form { <community_id> => "1", ... }
  def community_boxes=(hash)
    new_ids = hash.keys.map(&:to_i)
    existing_ids = community_ids

    to_create = new_ids - existing_ids
    to_delete = existing_ids - new_ids

    to_create.each{ |id| invitations.build(community_id: id) }

    invitations.each do |inv|
      if to_delete.include?(inv.community_id)
        inv.destroy if inv.persisted?
        invitations.delete(inv)
      end
    end
  end

  def signup_for(household)
    signups.where(household_id: household.id).first
  end

  def signup_count
    @signup_count ||= Signup.total_for_meal(self)
  end

  def signup_totals
    @signup_totals = Signup.totals_for_meal(self)
  end

  def spots_left
    @spots_left ||= [capacity - Signup.total_for_meal(self), 0].max
  end

  def portions(food_type)
    Signup.portions_for_meal(self, food_type)
  end

  def full?
    spots_left == 0
  end

  def in_past?
    served_at && served_at < Time.current
  end

  def menu_posted?
    MENU_ITEMS.any?{ |i| self[i].present? } || any_allergens?
  end

  def nonempty_menu_items
    MENU_ITEMS.map{ |i| [i, self[i]] }.to_h.reject{ |i, t| t.blank? }
  end

  # Returns a relation for all meals following the current one.
  # We break ties using community name and then ID.
  def following_meals
    self.class.joins(:community).
      where("served_at > ? OR served_at = ? AND
        (communities.name > ? OR communities.name = ? AND meals.id > ?)",
        served_at, served_at, community_name, community_name, id)
  end

  # Returns a relation for all meals before the current one.
  # We break ties using community name and then ID.
  def previous_meals
    self.class.joins(:community).
      where("served_at < ? OR served_at = ? AND
        (communities.name < ? OR communities.name = ? AND meals.id < ?)",
        served_at, served_at, community_name, community_name, id)
  end

  def formula
    @formula ||= Meals::Formula.for_meal(self)
  end

  def any_allergens?
    allergens.present? && allergens != ["none"]
  end

  def close!
    update_attribute(:status, "closed")
  end

  ALLERGENS.each do |allergen|
    define_method("allergen_#{allergen}?") do
      allergens.include?(allergen)
    end

    alias_method "allergen_#{allergen}", "allergen_#{allergen}?"

    define_method("allergen_#{allergen}=") do |yn|
      if yn == true || yn == "1"
        self.allergens << allergen unless send("allergen_#{allergen}?")
      else
        allergens.delete(allergen)
      end
    end
  end

  def duplicate_signups
    signups.reject(&:marked_for_destruction?).group_by(&:household_id).
      values.reject(&:one?).each(&:shift).flatten
  end

  private

  def menu_items_present?
    (['title'] + MENU_ITEMS).any?{ |a| self[a].present? }
  end

  def enough_capacity_for_current_signups
    if persisted? && !finalized? && capacity && capacity < (ttl = Signup.total_for_meal(self))
      errors.add(:capacity, "must be at least #{ttl} due to current signups")
    end
  end

  def title_and_entree_if_other_menu_items
    %w(title entrees).each do |attrib|
      if self[attrib].blank? && (menu_items_present? || allergens.present?)
        errors.add(attrib, "can't be blank if other menu items entered")
      end
    end
  end

  def at_least_one_community
    if invitations.reject(&:blank?).empty?
      errors.add(:invitations, "you must invite at least one community")
    end
  end

  def head_cook_presence
    if head_cook_assign.user_id.blank?
      head_cook_assign.errors.add(:user_id, "can't be blank")
      add_dummy_base_error
    end
  end

  def no_double_assignments
    %w(asst_cook table_setter cleaner).each do |role|
      marked_user_ids = {}
      send("#{role}_assigns").each do |a|
        if marked_user_ids[a.user_id]
          a.errors.add(:user_id, "user cannot be assigned to this role twice")
          add_dummy_base_error
        else
          marked_user_ids[a.user_id] = true
        end
      end
    end
  end

  def allergens_some_or_none_if_menu
    if menu_items_present? && allergens.empty?
      errors.add(:allergens, "at least one box must be checked if menu entered")
    end
  end

  def allergen_none_alone
    if allergen_none? && allergens.size > 1
      errors.add(:allergens, "none can't be selected if other allergens present")
    end
  end

  # Adds an error to the base object so that valid? returns false and
  # errors on associations are shown.
  def add_dummy_base_error
    errors.add(:__dummy, "x")
  end
end
