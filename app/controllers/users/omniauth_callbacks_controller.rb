class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  before_action :skip_authorization

  def google_oauth2
    auth = request.env["omniauth.auth"]

    # If invite token is present, try to find user by that.
    if (t = session[:invite_token]) && by_token = User.with_reset_password_token(t)

      # If we find them but they are logging in with the wrong google_email, notify them.
      if !by_token.google_email.nil? && by_token.google_email != auth.info[:email]
        set_flash_message(:error, :failure, kind: "Google",
          reason: "you must login with the Google ID #{by_token.google_email}")
        redirect_to login_url

      # If there is already a user with that google_email, log them in
      # INSTEAD of the one with the token. Shouldn't happen often.
      elsif by_email = User.from_omniauth(auth)
        login_and_clear_token(by_email, auth)

      # Else if the token is still valid, log them in and grab their google_email
      elsif by_token.reset_password_period_valid?
        login_and_clear_token(by_token, auth)

      else
        set_flash_message(:error, :failure, kind: "Google",
          reason: "your invitation has expired")
        redirect_to login_url
      end

      session[:invite_token] = nil

    # if no invite, try to find by google_email
    elsif by_email = User.from_omniauth(auth)

      by_email.update_for_oauth!(auth)
      sign_in_and_redirect by_email, event: :authentication

    else

      set_flash_message(:error, :failure, kind: "Google",
        reason: "your Google ID #{auth.info[:email]} was not found in the system")
      redirect_to login_url

    end
  end

  private

  def login_and_clear_token(user, auth)
    user.update_for_oauth!(auth)
    user.send(:clear_reset_password_token)
    sign_in_and_redirect user, event: :authentication
  end
end
