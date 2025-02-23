# frozen_string_literal: true

module People
  module Users
    # Handles redirect back from Google OAuth
    class OmniauthCallbacksController < Devise::OmniauthCallbacksController
      skip_after_action :verify_authorized

      def google_oauth2
        auth = request.env["omniauth.auth"]
        invite_token = request.env["omniauth.params"]["state"].presence
        by_google_id = User.from_omniauth(auth) # May be nil

        if auth.info[:email].blank?
          reason = "Google did not provide an email address. Please notify an administrator."
          fail_with_msg(reason: reason)
        # If invite token is present, try to find user by that.
        elsif invite_token && (by_token = User.with_reset_password_token(invite_token))
          if !by_token.reset_password_period_valid?
            fail_with_msg(reason: "your invitation has expired")

          # If we find them but they are signing in with the wrong google_email, notify them.
          elsif !by_token.google_email.nil? && by_token.google_email != auth.info[:email]
            fail_with_msg("you must sign in with the Google ID #{by_token.google_email}")

          # If there is a different user with that google_email, notify them.
          elsif by_google_id.present? && by_google_id != by_token
            fail_with_msg("your Google ID #{auth.info[:email]} is associated with another user")
          else
            clean_up_sign_in(by_token, auth)
          end
        # if no invite, try to find by google_email
        elsif by_google_id
          if by_google_id.confirmed? || by_google_id.email == by_google_id.google_email
            clean_up_sign_in(by_google_id, auth)
          else
            fail_with_msg("you must use an invititation when first signing in")
          end
        else
          fail_with_msg("your Google ID #{auth.info[:email]} was not found in the system")
        end
      end

      def failure
        unless browser.bot?
          Rails.logger.info("OAuth failed: #{failure_message}")
          Gather::ErrorReporter.instance.report(StandardError.new("OAuth failure"), env: request.env,
                                                                                    data: {failure_message: failure_message})
        end
        fail_with_msg("of an unspecified error. The administrators have been notified")
      end

      private

      def fail_with_msg(msg)
        set_flash_message(:error, :failure, kind: "Google", reason: msg)
        redirect_to(sign_in_url)
      end

      def clean_up_sign_in(user, auth)
        user.update_for_oauth!(auth)
        user.send(:clear_reset_password_token)

        # If the user wasn't confirmed before now, we don't let them sign in unless they used an invite
        # or their email matches their google_email. So if they got this far we can confirm.
        # We don't use user.confirm here because that might fail if the user's confirmation_sent_at
        # value is old, but we don't use that for initial confirmation.
        user.update_attribute(:confirmed_at, Time.current)

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
