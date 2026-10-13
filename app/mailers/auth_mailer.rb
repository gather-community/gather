# frozen_string_literal: true

# Contains email methods relating to user authentication and registration.
#
# WARNING: This class does not subclass ApplicationMailer so it doesn't inherit things like:
# - Default from address
# - Subdomain logic
# - Filtering of unconfirmed/fake users
# - Mapping of children without emails to guardians
#
# So each method in here should consider these things separately. Many of them don't apply, but care
# should be taken all the same.
class AuthMailer < Devise::Mailer
  include RecipientLocale
  include SubdomainSettable

  # Need to set `from` here separately because we're not inheriting from ApplicationMailer
  default template_path: "auth_mailer", from: Settings.email.from

  # Adds the notification settings footer, like ApplicationMailer.
  layout "mailer"

  def reset_password_instructions(user, token, opts = {})
    return if user.fake?
    set_notification_preferences_url(user)
    super(user.decorate, token, opts)
  end

  def cant_reset_password(user)
    return if user.fake?
    set_notification_preferences_url(user)
    @user = user.decorate
    mail(to: @user)
  end

  def confirmation_instructions(user, token, opts = {})
    return if user.fake?
    set_notification_preferences_url(user)
    super(user.decorate, token, opts)
  end

  def sign_in_invitation(user, token)
    return if user.fake? || user.email.blank?
    set_notification_preferences_url(user)
    @user = user.decorate
    @token = token
    @expiry_days = (Devise.reset_password_within / 1.day).to_i
    mail(to: @user.email, subject: default_i18n_subject)
  end

  private

  # Auth links point at the apex domain, but the settings page lives on the user's community subdomain.
  def set_notification_preferences_url(user)
    with_community_subdomain(user.community) { @notification_preferences_url = notification_preferences_url }
  end
end
