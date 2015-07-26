class User < ActiveRecord::Base
  devise :omniauthable, :trackable, omniauth_providers: [:google_oauth2]

  belongs_to :household

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
end
