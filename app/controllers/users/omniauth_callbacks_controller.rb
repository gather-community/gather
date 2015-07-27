class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google")
    else
      set_flash_message(:error, :failure, kind: "Google", reason: "UID not found. Please contact meal biller.")
      redirect_to root_path
    end
  end
end