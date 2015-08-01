class User < ActiveRecord::Base
  PHONE_TYPES = %w(home work mobile)

  devise :omniauthable, :trackable, omniauth_providers: [:google_oauth2]

  belongs_to :household

  scope :by_name, -> { order("first_name, last_name") }
  scope :by_active_and_name, -> { order("(CASE WHEN deleted_at IS NULL THEN 0 ELSE 1 END)").by_name }

  delegate :name, to: :household, prefix: true

  PHONE_TYPES.each do |p|
    phony_normalize "#{p}_phone", default_country_code: 'US'
    validates_plausible_phone "#{p}_phone", normalized_country_code: 'US'
  end

  normalize_attributes :email, :google_email, :first_name, :last_name

  validates :email, format: Devise.email_regexp, presence: true, uniqueness: true
  validates :google_email, format: Devise.email_regexp, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :household, presence: true
  validate :at_least_one_phone

  def self.from_omniauth(auth)
    # Find user
    if user = where(google_email: auth.info[:email]).first
      # Ensure provider and uid are set.
      user.provider = 'google_oauth2'
      user.uid = auth.uid
      user.save(validate: false)
    end
    user
  end

  def name
    "#{first_name} #{last_name}"
  end

  def format_phone(kind)
    read_attribute(:"#{kind}_phone").try(:phony_formatted, format: :national)
  end

  # Returns a string with all non-nil phone numbers
  def phones
    PHONE_TYPES.map{ |t| (p = format_phone(t)) ? "#{p} #{t[0]}" : nil }.compact.join(",")
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
