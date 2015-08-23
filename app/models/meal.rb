class Meal < ActiveRecord::Base

  DEFAULT_TIME = 18.hours + 15.minutes
  DEFAULT_CAPACITY = 64
  ALLERGENS = %w(gluten shellfish soy corn dairy eggs peanuts almonds none)
  DEFAULT_ASST_COOKS = 2
  DEFAULT_CLEANERS = 3
  MENU_ITEMS = %w(entrees side kids dessert notes)

  serialize :allergens, JSON

  belongs_to :location
  has_many :assignments
  has_one :head_cook_assign, ->{ where(role: "head_cook") }, class_name: "Assignment"
  has_many :asst_cook_assigns, ->{ where(role: "asst_cook") }, class_name: "Assignment"
  has_many :cleaner_assigns, ->{ where(role: "cleaner") }, class_name: "Assignment"
  has_one :head_cook, through: :head_cook_assign, source: :user
  has_many :asst_cooks, through: :asst_cook_assigns, source: :user
  has_many :cleaners, through: :cleaner_assigns, source: :user
  has_many :invitations
  has_many :communities, through: :invitations
  has_many :signups
  has_many :households, through: :signups

  scope :oldest_first, -> { order(served_at: :asc) }
  scope :newest_first, -> { order(served_at: :desc) }
  scope :future, -> { where("served_at >= ?", Time.now.midnight) }
  scope :worked_by, ->(user) do
    includes(:assignments).where("assignments.user_id" => user.id)
  end
  scope :inviting, ->(user) do
    includes(:invitations).where("invitations.community_id" => user.community_id)
  end
  scope :visible_to, ->(user) do
    joins("LEFT OUTER JOIN assignments ON assignments.meal_id = meals.id").
    joins("LEFT OUTER JOIN invitations ON invitations.meal_id = meals.id").
    joins("LEFT OUTER JOIN signups ON signups.meal_id = meals.id").
      where("invitations.community_id = ? OR assignments.user_id = ? OR signups.household_id = ?",
        user.community_id, user.id, user.household_id)
  end

  accepts_nested_attributes_for :head_cook_assign, reject_if: :all_blank
  accepts_nested_attributes_for :asst_cook_assigns, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :cleaner_assigns, reject_if: :all_blank, allow_destroy: true

  delegate :name, :abbrv, to: :location, prefix: true
  delegate :name, to: :head_cook, prefix: true

  before_validation do
    # Ensure head cook, even if blank, so we can add error to it.
    build_head_cook_assign if head_cook_assign.blank?
  end

  normalize_attributes :title, :entrees, :side, :kids, :dessert, :notes, :capacity

  validates :served_at, presence: true
  validates :location_id, presence: true
  validates :capacity, presence: true
  validate :title_and_entree_if_other_menu_items
  validate :at_least_one_community
  validate :head_cook_presence
  validate :no_double_assignments
  validate :allergens_some_or_none_if_menu
  validate :allergen_none_alone

  def self.new_with_defaults
    new(served_at: default_datetime, capacity: DEFAULT_CAPACITY, community_ids: Community.all.map(&:id))
  end

  def self.default_datetime
    (Date.today + 7.days).to_time + DEFAULT_TIME
  end

  def visible_to?(user)
    invited?(user) || worked_by?(user) || signed_up?(user.household)
  end

  def invited?(user)
    invitations.map(&:community_id).include?(user.community_id)
  end

  def worked_by?(user)
    assignments.map(&:user_id).include?(user.id)
  end

  def signed_up?(household)
    signups.map(&:household_id).include?(household.id)
  end

  # Ensures there is one head_cook assignment and 2 each of the others.
  # Creates blank ones if needed.
  def ensure_assignments
    build_head_cook_assign if head_cook_assign.nil?
    (DEFAULT_ASST_COOKS - asst_cook_assigns.size).times{ asst_cook_assigns.build }
    (DEFAULT_CLEANERS - cleaner_assigns.size).times{ cleaner_assigns.build }
  end

  def community_ids
    invitations.map(&:community_id)
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

  def spots_left
    @spots_left ||= [capacity - Signup.total_for_meal(self), 0].max
  end

  def menu_posted?
    entrees.present?
  end

  # Returns a relation for all meals following the current one.
  def following_meals
    self.class.where("served_at > ?", served_at)
  end

  # Returns a relation for all meals before the current one.
  def previous_meals
    self.class.where("served_at < ?", served_at)
  end

  def any_allergens?
    allergens.present? && allergens != ["none"]
  end

  (ALLERGENS).each do |allergen|
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

  private

  def menu_items_present?
    (['title'] + MENU_ITEMS).any?{ |a| self[a].present? }
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
    %w(asst_cook cleaner).each do |role|
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
