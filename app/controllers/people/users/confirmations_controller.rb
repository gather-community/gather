# frozen_string_literal: true

module People
  module Users
    # Handles reconfirming email, but not initial confirmation, as that is handled through the sign-in
    # invitation process.
    class ConfirmationsController < Devise::ConfirmationsController
      # GET /resource/confirmation?confirmation_token=abcdef
      def show
        self.resource = resource_class.confirm_by_token(params[:confirmation_token])
        yield(resource) if block_given?

        if resource.errors.empty? || resource.errors.all? { |e| e.type == :already_confirmed }
          handle_success
        elsif resource.errors.details[:email]&.first&.[](:error) == :confirmation_period_expired
          handle_expiry
        else
          raise StandardError, "Unexpected error(s) when confirming email: #{resource.errors.inspect}"
        end
      end

      protected

      def handle_success
        set_flash_message!(:notice, :confirmed)
        respond_with_navigational(resource) do
          if signed_in?(resource_name)
            # Devise sets a flash[:notice] which we will use as-is on the user page.
            redirect_to(user_path(resource))
          else
            # In this case we want to add a bit more context.
            flash[:notice] << " Please sign in to use Gather."
            redirect_to(root_path)
          end
        end
      end

      def handle_expiry
        respond_with_navigational(resource.errors, status: :unprocessable_entity) do
          if signed_in?(resource_name)
            flash[:alert] = "The confirmation period has expired. " \
              "Please use the 'Resend confirmation instructions' link below to try again."
            redirect_to(user_path(resource))
          else
            flash[:alert] = "The confirmation period has expired. " \
              "Please sign in using your old email address and try again."
            redirect_to(root_path)
          end
        end
      end
    end
  end
end
