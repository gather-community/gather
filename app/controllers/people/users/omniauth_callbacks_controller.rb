# frozen_string_literal: true

module People
  module Users
    # Handles redirect back from Google OAuth
    class OmniauthCallbacksController < Devise::OmniauthCallbacksController
      before_action :skip_authorization

      def google_oauth2
        Rails.logger.info("Entering google_oauth2 method")
        Rails.logger.info("Expected oauth state is #{session['omniauth.state']}")

        auth = request.env["omniauth.auth"]

        # If invite token is present, try to find user by that.
        if (t = session[:invite_token]) && (by_token = User.with_reset_password_token(t))

          if !by_token.reset_password_period_valid?
            set_flash_message(:error, :failure, kind: "Google", reason: "your invitation has expired")
            redirect_to(sign_in_url)

          # If we find them but they are signing in with the wrong google_email, notify them.
          elsif !by_token.google_email.nil? && by_token.google_email != auth.info[:email]
            set_flash_message(:error, :failure,
              kind: "Google", reason: "you must sign in with the Google ID #{by_token.google_email}")
            redirect_to(sign_in_url)

          # If there is already a user with that google_email, log them in
          # INSTEAD of the one with the token. Shouldn't happen often.
          elsif (by_email = User.from_omniauth(auth))
            store_id_clear_token_and_sign_in(by_email, auth)

          # Else log them in and grab their google_email
          else
            store_id_clear_token_and_sign_in(by_token, auth)
          end

          session[:invite_token] = nil

        # if no invite, try to find by google_email
        elsif (by_email = User.from_omniauth(auth))
          by_email.update_for_oauth!(auth)
          sign_in_remember_and_redirect(by_email)
        else
          set_flash_message(:error, :failure,
            kind: "Google", reason: "your Google ID #{auth.info[:email]} was not found in the system")
          redirect_to(sign_in_url)
        end
      end

      def failure
        unless browser.bot?
          Rails.logger.info("OAuth failed. See error email for more details.")
          ExceptionNotifier.notify_exception(StandardError.new("oauth failure"), env: request.env)
        end
        set_flash_message(:error, :failure,
          kind: "Google", reason: "of an unspecified error. The administrators have been notified")
        redirect_to(sign_in_url)
      end

      private

      def store_id_clear_token_and_sign_in(user, auth)
        user.update_for_oauth!(auth)
        user.send(:clear_reset_password_token)
        sign_in_remember_and_redirect(user)
      end

      def sign_in_remember_and_redirect(user)
        # We always set remember_me for OAuth sign-ins. So if someone signs in with Google
        # on a shared computer and doesn’t sign out explicitly, they stay signed into Gather.
        # BUT they should be explicitly signing out of Google too or that will stay logged in.
        # So they kind of need to remember to sign out anyway. The best workflow for such a person is
        # to use the Gather sign out link which then prompts them to sign out of Google. If somone wants
        # to be automatically forgotten on browser close they should use password auth.
        # And even then, they need to remember to turn off the 'resume where I left off' feature in some
        # browsers that doesn't clear session cookies on close.
        user.remember_me = true
        sign_in_and_redirect(user, event: :authentication)
      end
    end
  end
end
