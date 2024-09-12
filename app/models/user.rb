# frozen_string_literal: true

# Users are the key to the whole thing!

# Email confirmation info:
# Rules:
# * User must have email unless non-full-access or inactive
# * Email changes must be reconfirmed if user is already confirmed
# * Signing in with invitation code counts as confirmation since it proves email ownership
# * Directory only users can have emails (for e.g. reminders) but can't be confirmed
#   (this implies non-full-access user emails are NOT secure, but that should be OK)
#
# Sample Flows:
# 1. Adult created with unconfirmed email, signs in with invite, is confirmed
# 2. Adult created with unconfirmed email, admin changes email before sign-in, email change doesn't need
#    reconfirmation because not confirmed yet, user later signs in with invite, is confirmed
# 3. Confirmed adult deactivated, email removed (this unsets confirmation flag), new email added, user
#    reactivated, sent sign in invite, signs in, is confirmed
# 4. Unconfirmed adult deactivated, email removed, same as above
# 5. Unconfirmed adult deactivated, email stays in place, reactivated, same as above
# 6. Directory-only child created with no email, not confirmed, can't sign in, later converted to full access,
#    email must be added, still unconfirmed, sent sign in invite, etc.
# 7. Directory-only child created with email, not confirmed, can't sign in, later converted to full access,
#    sent sign in invite, signs in, is confirmed
class User < ApplicationRecord
  include Wisper.model
  include AttachmentFormable
  include Phoneable
  include Deactivatable
  include SemicolonDisallowable
  include CustomFields

  ROLES = %i[super_admin cluster_admin admin biller photographer calendar_coordinator
    meals_coordinator wikiist work_coordinator].freeze
  ADMIN_ROLES = %i[super_admin cluster_admin admin].freeze
  CONTACT_TYPES = %i[email text phone].freeze
  PASSWORD_MIN_ENTROPY = 16
  PASSWORD_STRENGTH_CHECKER_OPTIONS = {use_dictionary: true, min_entropy: PASSWORD_MIN_ENTROPY}

  acts_as_tenant :cluster
  rolify

  attr_accessor :changing_password
  alias_method :changing_password?, :changing_password

  attr_accessor :certify_13_or_older

  # Currently, :database_authenticatable is only needed for tha password reset token features
  devise :omniauthable, :trackable, :recoverable, :database_authenticatable, :rememberable,
    :confirmable, omniauth_providers: [:google_oauth2]

  belongs_to :household, inverse_of: :users
  belongs_to :job_choosing_proxy, class_name: "User"
  has_many :job_choosing_proxiers, class_name: "User", foreign_key: :job_choosing_proxy_id,
    inverse_of: :job_choosing_proxy, dependent: :nullify
  has_many :up_guardianships, class_name: "People::Guardianship", foreign_key: :child_id,
    dependent: :destroy, inverse_of: :child
  has_many :down_guardianships, class_name: "People::Guardianship", foreign_key: :guardian_id,
    dependent: :destroy, inverse_of: :guardian
  has_many :guardians, through: :up_guardianships
  has_one :memorial, class_name: "People::Memorial", inverse_of: :user
  has_many :memorial_messages, class_name: "People::MemorialMessage", inverse_of: :author
  has_many :children, through: :down_guardianships

  # We deliberately don't use dependent: :destroy here because we want to be able to search by user ID
  # in PermissionSyncJobs
  has_many :gdrive_synced_permissions, class_name: "GDrive::SyncedPermission", inverse_of: :user,
    dependent: nil

  has_many :group_memberships, class_name: "Groups::Membership", inverse_of: :user, dependent: :destroy
  has_one :group_mailman_user, class_name: "Groups::Mailman::User", inverse_of: :user, dependent: :destroy,
    autosave: false
  has_many :meal_assignments, class_name: "Meals::Assignment", inverse_of: :user, dependent: :destroy
  has_many :meal_costs, class_name: "Meals::Cost", foreign_key: :reimbursee_id,
    inverse_of: :reimbursee, dependent: :nullify
  has_many :work_assignments, class_name: "Work::Assignment", inverse_of: :user, dependent: :destroy
  has_many :work_shares, class_name: "Work::Share", inverse_of: :user, dependent: :destroy

  scope :real, -> { where(fake: false) }
  scope :all_in_community_or_adult_in_cluster, lambda { |c|
    joins(household: :community)
      .where("communities.id = ? OR users.child = 'f'", c.id)
      .where("communities.cluster_id = ?", c.cluster_id)
  }
  scope :in_community, ->(id) { joins(:household).where(households: {community_id: id}) }
  scope :by_name, -> { alpha_order(:first_name).alpha_order(:last_name) }
  scope :by_unit, -> { joins(:household).order("households.unit_num, households.unit_suffix") }
  scope :sorted_by, ->(s) { (s == "unit") ? by_unit : by_name }
  scope :by_name_adults_first, -> { order(arel_table[:child].eq(true)).by_name }
  scope :inactive_last, -> { order(arel_table[:deactivated_at].not_eq(nil)) }
  scope :including_communities, -> { includes(household: :community) }
  scope :by_community_and_name, -> { including_communities.order("communities.name").by_name }
  scope :by_birthday, lambda {
    order(Arel.sql(%i[month day year].map { |d| "EXTRACT(#{d} FROM birthdate)" }.join(", ")))
  }
  scope :active_or_assigned_to, lambda { |meal|
    where(arel_table[:deactivated_at].eq(nil).or(arel_table[:id].in(meal.assignments.map(&:user_id))))
  }
  scope :matching, lambda { |q|
    joins(:household)
      .where("(first_name || ' ' || last_name) ILIKE ?", "%#{q}%")
      .or( # Exact unit num without suffix
        joins(:household)
          .where("unit_num::varchar ILIKE ?", q)
      )
      .or( # Exact unit num and suffix
        joins(:household)
          .where("(COALESCE(unit_num::varchar, '') || COALESCE(unit_suffix, '')) ILIKE ?", q)
      )
      .or( # Exact unit num and suffix with hyphen
        joins(:household)
          .where("(COALESCE(unit_num::varchar, '') || '-' || COALESCE(unit_suffix, '')) ILIKE ?", q)
      )
  }
  scope :with_full_name, ->(n) { where("LOWER(first_name || ' ' || last_name) = ?", n.downcase) }
  scope :can_be_guardian, -> { active.where(child: false) }
  scope :adults, -> { where(child: false) }
  scope :full_access, -> { where(full_access: true) }
  scope :in_life_stage, ->(s) { (s.to_sym == :any) ? all : where(child: s.to_sym == :child) }

  # Returns users (including children) directly in the household PLUS any children associated by parentage,
  # even if they aren't directly in the household via the foreign key.
  scope :in_household, lambda { |h|
    parentage = "SELECT child_id FROM people_guardianships g INNER JOIN users u ON g.guardian_id = u.id
      WHERE u.household_id = ?"
    where(household: h).or(where("users.id IN (#{parentage})", h.id))
  }

  ROLES.each do |role|
    # Using these scopes instead of with_role helps avoid invalid role mistakes.
    scope :"with_#{role}_role", -> { with_role(role) }
  end

  delegate :name, to: :household, prefix: true
  delegate :account_for, :credit_exceeded?, :other_cluster_communities, to: :household
  delegate :community_id, :community_name, :community_abbrv,
    :unit_num, :unit_num_and_suffix, :vehicles, to: :household
  delegate :community, to: :household, allow_nil: true
  delegate :str, :str=, to: :birthday, prefix: :birthday
  delegate :age, :birth_year, to: :birthday
  delegate :subdomain, to: :community
  delegate :country_code, to: :community, allow_nil: true

  normalize_attributes :email, :google_email, :paypal_email, with: :email
  normalize_attributes :first_name, :last_name, :preferred_contact

  handle_phone_types :mobile, :home, :work # In order of general preference

  # Contact email does not have to be unique because some people share them (grrr!)
  validates :email, format: Devise.email_regexp, allow_blank: true
  validates :email, presence: true, if: :email_required?
  validates :email, uniqueness: true, allow_nil: true
  validates :google_email, format: Devise.email_regexp, uniqueness: true,
    unless: ->(u) { u.google_email.blank? }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :up_guardianships, presence: true, if: :child?
  validates :password, presence: true, if: :password_required?
  validates :password, password_strength: PASSWORD_STRENGTH_CHECKER_OPTIONS, if: :password_required_and_not_blank?

  validates :password, confirmation: true
  validate :certify_13_or_older_if_full_access_child_or_child_becoming_adult
  validate :household_present
  validate { birthday.validate }
  validate :birthdate_age_certification_agreement

  disallow_semicolons :first_name, :last_name

  has_one_attached :photo
  accepts_attachment_via_form :photo
  validates :photo, content_type: {in: %w[image/jpg image/jpeg image/png image/gif]},
    file_size: {max: Settings.photos.max_size_mb.megabytes}

  accepts_nested_attributes_for :household
  accepts_nested_attributes_for :up_guardianships, reject_if: :all_blank, allow_destroy: true

  before_validation :normalize

  # This is needed for remembering users across sessions because users don't always have passwords.
  before_create { self.remember_token ||= UniqueTokenGenerator.generate(self.class, :remember_token) }
  before_save { raise People::AdultWithGuardianError if adult? && guardians.present? }
  before_save :unconfirm_if_no_email

  after_validation :log_errors, if: Proc.new { |m| m.errors }

  def log_errors
    Rails.logger.debug("USER-VALIDATION-ERRORS-LINE", errors: errors.full_messages.join(";"))
  end

  custom_fields :custom_data, spec: lambda { |user|
    user.community && YAML.safe_load(user.community.settings.people.user_custom_fields_spec || "")
  }

  def self.from_omniauth(auth)
    return nil if auth.info[:email].blank?
    find_by(google_email: auth.info[:email])
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

  # Duck type.
  def users
    [self]
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
    self.provider = "google_oauth2"
    self.uid = auth.uid
    save(validate: false)
  end

  def name
    "#{first_name} #{last_name}#{active? ? nil : " (Inactive)"}"
  end

  def life_stage
    child? ? "child" : "adult"
  end

  def birthday?
    birthdate.present?
  end

  def birthday
    @birthday ||= People::Birthday.new(self)
  end

  def paypal_email_or_default
    paypal_email || email
  end

  def privacy_settings=(settings)
    settings = {} if settings.blank?
    settings.each { |k, v| settings[k] = ["1", "true", true].include?(v) }
    self[:privacy_settings] = settings
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
    reset_calendar_token! if calendar_token.blank?
  end

  def reset_calendar_token!
    update_attribute(:calendar_token, UniqueTokenGenerator.generate(self.class, :calendar_token))
  end

  # Exposing this as a public method.
  def reset_reset_password_token!
    set_reset_password_token
  end

  def send_reset_password_instructions
    super if full_access?
  end

  # All roles are currently global.
  # It might be tempting to scope e.g. meals_coordinator by community, but that would only make sense
  # if someone can e.g. be a meals_coordinator in multiple communities, which they can't.
  # Community scoping is already represented by the user's community or cluster affiliation.
  # The below methods are used to populate and receive params for the check boxes in the user form.
  ROLES.each do |role|
    define_method("role_#{role}") do
      has_role?(role)
    end

    define_method("role_#{role}=") do |bool|
      ["1", "true", true].include?(bool) ? add_role(role) : remove_role(role)
    end
  end

  # Efficiently does role lookups for global roles (those without associated calendars) by caching
  # the user's roles. The has_role? method provided by Rolify does not do any caching which results in
  # a ton of unnecessary DB requests on some pages.
  def global_role?(role)
    global_roles[role].present?
  end

  def adult?
    !child?
  end

  def full_access_child?
    child? && full_access?
  end

  def certify_13_or_older?
    ["1", "true", true].include?(certify_13_or_older)
  end

  def email_required?
    full_access? && active?
  end

  # Devise method, instantly signs out user if returns false.
  def active_for_authentication?
    # We don't return false for full access inactive users because they
    # can still see some pages.
    super && full_access?
  end

  def never_signed_in?
    sign_in_count.zero?
  end

  private

  def normalize
    unless child?
      self.full_access = true
      up_guardianships.destroy_all
    end
    unless full_access?
      self.google_email = nil
      self.job_choosing_proxy_id = nil
      self.reset_password_token = nil
      self.confirmed_at = nil
      roles.destroy_all
    end
  end

  def household_present
    return if household_id.present? || household.present? && !household.marked_for_destruction?
    errors.add(:household_id, :blank)
  end

  # Returns a hash of global roles (those with no associated resource) indexed by name.
  def global_roles
    @global_roles ||= roles.where(resource_id: nil).to_a.index_by(&:name).with_indifferent_access
  end

  def password_required?
    changing_password? || password.present? || password_confirmation.present?
  end

  def password_required_and_not_blank?
    password_required? && password.present?
  end

  def certify_13_or_older_if_full_access_child_or_child_becoming_adult
    return if ["1", "true", true].include?(certify_13_or_older)
    if full_access_child? && (new_record? || full_access_changed?)
      errors.add(:certify_13_or_older, :accepted_full_access)
    end
    errors.add(:certify_13_or_older, :accepted_becoming_adult) if adult? && child_changed?
  end

  def unconfirm_if_no_email
    # This is currently only applicable if the user is inactive.
    self.confirmed_at = nil if email.blank?
  end

  def birthdate_age_certification_agreement
    return if adult? || !full_access? || !birthday? || !age || age >= 13
    errors.add(:birthday_str, :too_young)
  end
end
