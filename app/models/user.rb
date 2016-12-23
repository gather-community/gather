class User < ActiveRecord::Base
  include Deactivatable, Phoneable
  rolify

  ROLES = %i(super_admin cluster_admin admin biller)
  CONTACT_TYPES = %i(email text phone)

  # Currently, :database_authenticatable is only needed for tha password reset token features
  devise :omniauthable, :trackable, :recoverable, :database_authenticatable, omniauth_providers: [:google_oauth2]

  belongs_to :household, inverse_of: :users
  has_many :up_guardianships, class_name: "People::Guardianship", foreign_key: :guardian_id
  has_many :down_guardianships, class_name: "People::Guardianship", foreign_key: :child_id
  has_many :guardians, through: :up_guardianships
  has_many :children, through: :down_guardianships
  has_many :assignments

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
  delegate :str, :str=, to: :birthdate_wrapper, prefix: :birthdate
  delegate :age, to: :birthdate_wrapper

  attr_accessor :photo_destroy

  normalize_attributes :email, :google_email, with: :email
  normalize_attributes :first_name, :last_name

  handle_phone_types :home, :work, :mobile

  # Contact email does not have to be unique because some people share them (grrr!)
  validates :email, format: Devise.email_regexp
  validates :email, presence: true, if: :adult?
  validates :google_email, format: Devise.email_regexp, uniqueness: true,
    unless: ->(u) { u.google_email.blank? }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :household_id, presence: true
  validates :guardians, presence: true, if: :child?
  validate :at_least_one_phone, if: ->(u){ u.new_record? }
  validate { birthdate_wrapper.validate }

  has_attached_file :photo,
    styles: { thumb: "150x150#", medium: "300x300#" },
    default_url: "missing/users/:style.png"
  validates_attachment_content_type :photo, content_type: %w(image/jpg image/jpeg image/png image/gif)
  validates_attachment_size :photo, less_than: Settings.photos.max_size

  before_save do
    photo.destroy if photo_destroy?
    raise People::AdultWithGuardianError if adult? && guardians.present?
  end

  def self.from_omniauth(auth)
    where(google_email: auth.info[:email]).first
  end

  def photo_destroy?
    photo_destroy.to_i == 1
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

  def birthdate_wrapper
    @birthdate_wrapper ||= People::Birthdate.new(self)
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

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(calendar_token: token).first
    end
  end
end
