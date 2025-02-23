# frozen_string_literal: true

module People
  module Users
    # Handles resetting password.
    class PasswordsController < Devise::PasswordsController
      def create
        super do |user|
          AuthMailer.cant_reset_password(user).deliver_later unless user.full_access?
        end
      end

      def update
        # This block is called after the password reset attempt. So we check if the password reset succeeded
        # (i.e. that the user is valid), unconfirmed, and not pending_reconfirmation.
        # If so, we can confirm the user, since we use the password reset mechanism for our sign in invites,
        # and those also serve as email confirmations.
        # More generally speaking, if the user successfully resets their password via email, they
        # must control the email we have on file for them, so we can confirm them.
        # The exception to this is if the user is reconfirming (upon email change), in which case
        # we don't confirm them, since the above no longer holds in that case.
        super do |user|
          # NOTE: Using .valid? here instead of .errors.empty? ends up removing the errors from the object.
          if user.errors.empty? && !user.confirmed? && !user.pending_reconfirmation?
            # We don't use user.confirm here because that might fail if the user's confirmation_sent_at
            # value is old, but we don't use that for initial confirmation.
            user.update_attribute(:confirmed_at, Time.current)
          end
        end
      end
    end
  end
end
