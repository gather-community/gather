# frozen_string_literal: true

# Contains email methods relating to user authentication and registration.
class AuthMailer < Devise::Mailer
  include SubdomainSettable

  # Need to set `from` here separately because we're not inheriting from ApplicationMailer
  default template_path: "auth_mailer", from: Settings.email.from

  def reset_password_instructions(user, token, opts = {})
    return if user.fake?
    super(user.decorate, token, opts)
  end

  def confirmation_instructions(user, token, opts = {})
    return if user.fake?
    super(user.decorate, token, opts)
  end

  def sign_in_invitation(user, token)
    return if user.fake?
    @user = user.decorate
    @token = token
    mail(to: @user.email, subject: default_i18n_subject)
  end
end
