class User < ActiveRecord::Base
  PHONE_TYPES = %w(home work mobile)

  # Currently, :database_authenticatable is only needed for tha password reset token features
  devise :omniauthable, :trackable, :recoverable, :database_authenticatable, omniauth_providers: [:google_oauth2]

  belongs_to :household

  scope :by_name, -> { order("first_name, last_name") }
  scope :by_active_and_name, -> { order("(CASE WHEN deleted_at IS NULL THEN 0 ELSE 1 END)").by_name }
  scope :active, -> { where(deleted_at: nil) }
  scope :active_or_assigned_to, ->(meal) do
    t = arel_table
    where(t[:deleted_at].eq(nil).or(t[:id].in(meal.assignments.map(&:user_id))))
  end
  scope :never_logged_in, -> { where(sign_in_count: 0) }

  delegate :full_name, to: :household, prefix: true
  delegate :over_limit?, to: :household, prefix: false
  delegate :community, :community_id, :community_name, to: :household

  PHONE_TYPES.each do |p|
    phony_normalize "#{p}_phone", default_country_code: 'US'
    validates_plausible_phone "#{p}_phone", normalized_country_code: 'US'
  end

  normalize_attributes :email, :google_email, :first_name, :last_name

  validates :email, format: Devise.email_regexp, presence: true, uniqueness: true
  validates :google_email, format: Devise.email_regexp, uniqueness: true,
    unless: ->(u) { u.google_email.blank? }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :household_id, presence: true
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
    "#{first_name} #{last_name}" << (deleted? ? " (Inactive)" : "")
  end

  def format_phone(kind)
    read_attribute(:"#{kind}_phone").try(:phony_formatted, format: :national)
  end

  # Returns a string with all non-nil phone numbers
  def phones
    PHONE_TYPES.map{ |t| (p = format_phone(t)) ? "#{p} #{t[0]}" : nil }.compact
  end

  def soft_delete!
    update_attribute(:deleted_at, Time.current)
  end

  def undelete!
    update_attribute(:deleted_at, nil)
  end

  def deleted?
    deleted_at.present?
  end

  def active_for_authentication?
    super && !deleted?
  end

  private

  def at_least_one_phone
    errors.add(:mobile_phone, "You must enter at least one phone number") if no_phones?
  end

  def no_phones?
    [home_phone, mobile_phone, work_phone].compact.empty?
  end

end
