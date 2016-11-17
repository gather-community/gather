class User < ActiveRecord::Base
  include Deactivatable
  rolify

  PHONE_TYPES = %w(home work mobile)
  ROLES = %i(super_admin cluster_admin admin biller)

  # Currently, :database_authenticatable is only needed for tha password reset token features
  devise :omniauthable, :trackable, :recoverable, :database_authenticatable, omniauth_providers: [:google_oauth2]

  belongs_to :household, inverse_of: :users
  belongs_to :guardian, class_name: "User", inverse_of: :children
  has_many :assignments
  has_many :children, class_name: "User", foreign_key: :guardian_id, inverse_of: :guardian

  scope :in_community, ->(id) { joins(:household).where("households.community_id = ?", id) }
  scope :by_name, -> { order("first_name, last_name") }
  scope :by_community_and_name, -> { includes(household: :community).order("communities.name").by_name }
  scope :by_active_and_name, -> { order("users.deactivated_at IS NOT NULL").by_name }
  scope :active_or_assigned_to, ->(meal) do
    t = arel_table
    where(t[:deactivated_at].eq(nil).or(t[:id].in(meal.assignments.map(&:user_id))))
  end
  scope :never_logged_in, -> { where(sign_in_count: 0) }
  scope :matching, ->(q) { where("(first_name || ' ' || last_name) ILIKE ?", "%#{q}%") }

  delegate :name, :full_name, to: :household, prefix: true
  delegate :account_for, :credit_exceeded?, to: :household
  delegate :community_id, :community_name, :community_abbrv, to: :household
  delegate :community, to: :household, allow_nil: true

  PHONE_TYPES.each do |p|
    phony_normalize "#{p}_phone", default_country_code: 'US'
    validates_plausible_phone "#{p}_phone", normalized_country_code: 'US', country_number: '1'
  end

  normalize_attributes :email, :google_email, with: :email
  normalize_attributes :first_name, :last_name

  # Contact email does not have to be unique because some people share them (grrr!)
  validates :email, format: Devise.email_regexp
  validates :email, presence: true, if: :adult?
  validates :google_email, format: Devise.email_regexp, uniqueness: true,
    unless: ->(u) { u.google_email.blank? }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :household_id, presence: true
  validates :guardian_id, presence: true, if: :child?
  validate :at_least_one_phone, if: ->(u){ u.new_record? }

  def self.from_omniauth(auth)
    where(google_email: auth.info[:email]).first
  end

  # Ensures provider and uid are set.
  def update_for_oauth!(auth)
    self.google_email = auth.info[:email]
    self.provider = 'google_oauth2'
    self.uid = auth.uid
    save(validate: false)
  end

  def name
    "#{first_name} #{last_name}" << (active? ? "" : " (Inactive)")
  end

  # Returns formatted phone number, except if phone number has errors, returns raw value w/o +.
  def format_phone(kind)
    attrib = :"#{kind}_phone"
    if errors[attrib].any?
      read_attribute(attrib).try(:sub, /\A\+/, "")
    else
      read_attribute(attrib).try(:phony_formatted, format: :national)
    end
  end

  def age
    if has_full_birthdate?
      today = Date.today
      bday_this_year = Date.new(today.year, birthdate.month, birthdate.day)
      today.year - birthdate.year - (bday_this_year > today ? 1 : 0)
    else
      nil
    end
  end

  def has_full_birthdate?
    birthdate && birthdate.year != 1
  end

  def any_assignments?
    assignments.any?
  end

  def activate!
    super
    household.user_activated
  end

  def deactivate!
    super
    household.user_deactivated
  end

  # Returns a string with all non-nil phone numbers
  def phones
    PHONE_TYPES.map{ |t| (p = format_phone(t)) ? "#{p} #{t[0]}" : nil }.compact
  end

  def ensure_calendar_token!
    reset_calendar_token! unless calendar_token.present?
  end

  def reset_calendar_token!
    update_attribute(:calendar_token, generate_token)
  end

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
    errors.add(:mobile_phone, "You must enter at least one phone number") if adult? && no_phones?
  end

  def no_phones?
    [home_phone, mobile_phone, work_phone].compact.empty?
  end

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(calendar_token: token).first
    end
  end
end
