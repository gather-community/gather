# frozen_string_literal: true

module People
  module Users
    # Handles redirect back from Google OAuth
    class OmniauthCallbacksController < Devise::OmniauthCallbacksController
      skip_after_action :verify_pundit_authorization

      def google_oauth2
        auth = request.env["omniauth.auth"]
        invite_token = request.env["omniauth.params"]["state"].presence
        by_google_id = User.from_omniauth(auth) # May be nil

        if auth.info[:email].blank?
          fail_with_reason(:no_email)
        # If invite token is present, try to find user by that.
        elsif invite_token && (by_token = User.with_reset_password_token(invite_token))
          if !by_token.reset_password_period_valid?
            fail_with_reason(:invitation_expired)

          # If we find them but they are signing in with the wrong google_email, notify them.
          elsif !by_token.google_email.nil? && by_token.google_email != auth.info[:email]
            fail_with_reason(:wrong_google_id, google_id: by_token.google_email)

          # If there is a different user with that google_email, notify them.
          elsif by_google_id.present? && by_google_id != by_token
            fail_with_reason(:google_id_taken, google_id: auth.info[:email])
          else
            clean_up_sign_in(by_token, auth)
          end
        # if no invite, try to find by google_email
        elsif by_google_id
          if by_google_id.confirmed? || by_google_id.email == by_google_id.google_email
            clean_up_sign_in(by_google_id, auth)
          else
            fail_with_reason(:invitation_required)
          end
        else
          fail_with_reason(:google_id_not_found, google_id: auth.info[:email])
        end
      end

      def failure
        error_type = request.env["omniauth.error.type"]
        Rails.logger.info("OAuth failed: #{error_type} #{failure_message}")
        case error_type
        when :access_denied
          # User cancelled on Google's consent screen.
          fail_with_reason(:cancelled)
        when :csrf_detected
          # Callback was replayed (back button, tab restore) after its state was already used.
          if user_signed_in?
            redirect_to(after_sign_in_path_for(current_user))
          else
            fail_with_reason(:session_expired)
          end
        else
          report_unexpected_failure(error_type)
        end
      end

      private

      def report_unexpected_failure(error_type)
        unless browser.bot?
          Gather::ErrorReporter.instance.report(StandardError.new("OAuth failure"),
            data: {error_type: error_type, failure_message: failure_message})
        end
        fail_with_reason(:unexpected)
      end

      def fail_with_reason(key, **interpolations)
        reason = t("people.users.omniauth_failure_reasons.#{key}", **interpolations)
        set_flash_message(:error, :failure, kind: "Google", reason: reason) # rubocop:disable Gather/HardCodedString -- brand name
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
