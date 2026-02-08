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
  # Need to set `from` here separately because we're not inheriting from ApplicationMailer
  default template_path: "auth_mailer", from: Settings.email.from

  def reset_password_instructions(user, token, opts = {})
    return if user.fake?
    super(user.decorate, token, opts)
  end

  def cant_reset_password(user)
    return if user.fake?
    @user = user.decorate
    mail(to: @user)
  end

  def confirmation_instructions(user, token, opts = {})
    return if user.fake?
    super(user.decorate, token, opts)
  end

  def sign_in_invitation(user, token)
    return if user.fake? || user.email.blank?
    @user = user.decorate
    @token = token
    @expiry_days = (Devise.reset_password_within / 1.day).to_i
    mail(to: @user.email, subject: default_i18n_subject)
  end
end
