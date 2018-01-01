class User < ApplicationRecord
  include Deactivatable, Phoneable, PhotoDestroyable

  ROLES = %i(super_admin cluster_admin admin biller photographer meals_coordinator wikiist)
  CONTACT_TYPES = %i(email text phone)

  acts_as_tenant(:cluster)
  rolify

  # Currently, :database_authenticatable is only needed for tha password reset token features
  devise :omniauthable, :trackable, :recoverable, :database_authenticatable, :rememberable,
    omniauth_providers: [:google_oauth2]

  belongs_to :household, inverse_of: :users
  has_many :up_guardianships, class_name: "People::Guardianship", foreign_key: :child_id,
    dependent: :destroy
  has_many :down_guardianships, class_name: "People::Guardianship", foreign_key: :guardian_id,
    dependent: :destroy
  has_many :guardians, through: :up_guardianships
  has_many :children, through: :down_guardianships
  has_many :assignments

  scope :active, -> { where(deactivated_at: nil) }
  scope :all_in_community_or_adult_in_cluster, ->(c) { joins(household: :community).
    where("communities.id = ? OR users.child = 'f' AND communities.cluster_id = ?", c.id, c.cluster_id) }
  scope :in_community, ->(id) { joins(:household).where("households.community_id = ?", id) }
  scope :in_cluster, ->(id) { joins(household: :community).where("communities.cluster_id = ?", id) }
  scope :by_name, -> { order("LOWER(first_name), LOWER(last_name)") }
  scope :by_unit, -> { joins(:household).order("households.unit_num") }
  scope :by_active, -> { order("users.deactivated_at IS NOT NULL") }
  scope :sorted_by, ->(s) { s == "unit" ? by_unit : by_name }
  scope :by_name_adults_first, -> {
    order("CASE WHEN child = 't' THEN 1 ELSE 0 END, LOWER(first_name), LOWER(last_name)") }
  scope :by_community_and_name, -> { includes(household: :community).order("communities.name").by_name }
  scope :active_or_assigned_to, ->(meal) do
    t = arel_table
    where(t[:deactivated_at].eq(nil).or(t[:id].in(meal.assignments.map(&:user_id))))
  end
  scope :never_signed_in, -> { where(sign_in_count: 0) }
  scope :matching, ->(q) { where("(first_name || ' ' || last_name) ILIKE ?", "%#{q}%") }
  scope :can_be_guardian, -> { active.where(child: false) }
  scope :adults, -> { where(child: false) }
  scope :in_life_stage, ->(s) { s.to_sym == :any ? all : where(child: s.to_sym == :child) }

  ROLES.each do |role|
    # Using these scopes instead of with_role helps avoid invalid role mistakes.
    scope :"with_#{role}_role", -> { with_role(role) }
  end

  delegate :name, to: :household, prefix: true
  delegate :account_for, :credit_exceeded?, :other_cluster_communities, to: :household
  delegate :community_id, :community_name, :community_abbrv, :cluster, :unit_num, :vehicles, to: :household
  delegate :community, to: :household, allow_nil: true
  delegate :str, :str=, to: :birthdate_wrapper, prefix: :birthdate
  delegate :age, to: :birthdate_wrapper
  delegate :subdomain, to: :community

  normalize_attributes :email, :google_email, with: :email
  normalize_attributes :first_name, :last_name, :preferred_contact

  handle_phone_types :mobile, :home, :work # In order of general preference

  # Contact email does not have to be unique because some people share them (grrr!)
  validates :email, format: Devise.email_regexp, allow_blank: true
  validates :email, presence: true, if: :adult?
  validates :google_email, format: Devise.email_regexp, uniqueness: true,
    unless: ->(u) { u.google_email.blank? }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :up_guardianships, presence: true, if: :child?
  validate :household_present
  validate :at_least_one_phone, if: ->(u){ u.new_record? }
  validate { birthdate_wrapper.validate }

  has_attached_file :photo,
    styles: { thumb: "150x150#", medium: "300x300#" },
    default_url: "missing/users/:style.png"
  validates_attachment_content_type :photo, content_type: %w(image/jpg image/jpeg image/png image/gif)
  validates_attachment_size :photo, less_than: (Settings.photos.max_size_mb || 8).megabytes

  accepts_nested_attributes_for :household
  accepts_nested_attributes_for :up_guardianships, reject_if: :all_blank, allow_destroy: true

  # This is needed for remembering users across sessions because users don't always have passwords.
  before_create do
    self.remember_token ||= Devise.friendly_token
  end

  before_save do
    raise People::AdultWithGuardianError if adult? && guardians.present?
  end

  before_destroy do
    photo.destroy
  end

  def self.from_omniauth(auth)
    where(google_email: auth.info[:email]).first
  end

  # Transient variable indicating whether the User's household is being edited by setting the ID.
  # The alternative is to edit it by using nested attributes. Used only in rendering the form.
  def household_by_id?
    @household_by_id
  end
  alias_method :household_by_id, :household_by_id?

  # Setter for household_by_id?
  def household_by_id=(val)
    @household_by_id = val.is_a?(String) ? val == "true" : val
  end

  # Includes primary household plus any households affiliated by parentage.
  # For the case where children live in multiple households.
  # Alternatives for future refactors could be:
  # 1. children have multiple households
  # 2. children have household = nil and everything is determined by parentage. This may be better,
  #    would just have to remove the null constraint on household_id and think through implications.
  def all_households
    [household].concat(guardians.map(&:household)).uniq.shuffle
  end

  # Ensures provider and uid are set.
  def update_for_oauth!(auth)
    self.google_email = auth.info[:email]
    self.provider = 'google_oauth2'
    self.uid = auth.uid
    save(validate: false)
  end

  # We assume that people always want to stay logged in!
  def remember_me
    true
  end

  def name
    "#{first_name} #{last_name}" << (active? ? "" : " (Inactive)")
  end

  def birthday
    birthdate_wrapper
  end

  def birthdate_wrapper
    @birthdate_wrapper ||= People::Birthdate.new(self)
  end

  def privacy_settings=(settings)
    settings = {} if settings.blank?
    settings.each do |k,v|
      settings[k] = v == "1" || v == "true" || v == true
    end
    write_attribute(:privacy_settings, settings)
  end

  def any_assignments?
    assignments.any?
  end

  def activate
    super
    household.user_activated
  end

  def deactivate
    super
    household.user_deactivated
  end

  def ensure_calendar_token!
    reset_calendar_token! unless calendar_token.present?
  end

  def reset_calendar_token!
    update_attribute(:calendar_token, generate_token)
  end

  # All roles are currently global.
  # It might be tempting to scope e.g. meals_coordinator by community, but that would only make sense
  # if someone can be a meals_coordinator in multiple communities, which they can't.
  # Community scoping is already represented by the user's community or cluster affiliation.
  ROLES.each do |role|
    define_method("role_#{role}") do
      has_role?(role)
    end

    define_method("role_#{role}=") do |bool|
      bool == true || bool == "1" ? add_role(role) : remove_role(role)
    end
  end

  def adult?
    !child?
  end

  # Devise method, instantly signs out user if returns false.
  def active_for_authentication?
    # We don't return false for adult inactive users because they
    # can still see some pages.
    adult?
  end

  private

  def at_least_one_phone
    errors.add(:phone, "You must enter at least one phone number") if adult? && no_phones?
  end

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(calendar_token: token).first
    end
  end

  def household_present
    unless household_id.present? || household.present? && !household.marked_for_destruction?
      errors.add(:household_id, :blank)
    end
  end
end
