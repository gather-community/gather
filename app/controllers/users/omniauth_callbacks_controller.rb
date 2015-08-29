class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]

    # If invite token is present, try to find user by that.
    if (t = session[:invite_token]) && @user = User.with_reset_password_token(t)

      if !@user.google_email.nil? && @user.google_email != auth.info[:email]
        set_flash_message(:error, :failure, kind: "Google",
          reason: "you must login with the Google ID #{@user.google_email}")
        redirect_to root_path
      elsif @user.reset_password_period_valid?
        @user.update_for_oauth!(auth)
        @user.send(:clear_reset_password_token)
        sign_in_and_redirect @user, event: :authentication
      else
        set_flash_message(:error, :failure, kind: "Google",
          reason: "your invitation has expired")
        redirect_to root_path
      end
      session[:invite_token] = nil

    elsif @user = User.from_omniauth(auth)

      @user.update_for_oauth!(auth)
      sign_in_and_redirect @user, event: :authentication

    else

      set_flash_message(:error, :failure, kind: "Google",
        reason: "your Google ID #{auth.info[:email]} was not found in the system")
      redirect_to root_path

    end
  end
end
