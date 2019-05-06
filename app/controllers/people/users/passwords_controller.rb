# frozen_string_literal: true

module People
  module Users
    # Handles resetting password.
    class PasswordsController < Devise::PasswordsController
      protected

      # This method is called only upon a successful password reset, so we are hijacking it to
      # also set confirmed = true since we use the password reset mechanism for our sign in invites,
      # and those also serve as email confirmations.
      # More generally speaking, if the user successfully resets their password via email, they
      # must control the email we have on file for them, so we can confirm them.
      # The exception to this is if the user is reconfirming (upon email change), in which case
      # we don't confirm them, since the above no longer holds in that case.
      def after_resetting_password_path_for(user)
        user.update!(confirmed_at: Time.current) unless user.confirmed? || user.pending_reconfirmation?
        after_sign_in_path_for(user)
      end
    end
  end
end
