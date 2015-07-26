class User < ActiveRecord::Base
  devise :omniauthable, :trackable, omniauth_providers: [:google_oauth2]

  belongs_to :household

  %w(home_phone work_phone mobile_phone).each do |p|
    phony_normalize p, default_country_code: 'US'
    validates_plausible_phone p, normalized_country_code: 'US'
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

  private

  def at_least_one_phone
    errors.add(:base, "You must enter at least one phone number") if no_phones?
  end

  def no_phones?
    [home_phone, mobile_phone, work_phone].compact.empty?
  end
end
