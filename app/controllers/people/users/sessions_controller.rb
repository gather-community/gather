# frozen_string_literal: true

module People
  module Users
    # Handles logging in with password.
    class SessionsController < Devise::SessionsController
      helper_method :reset_password_path

      def reset_password_path
        # If a token is passed as a param and the user clicks 'forgot password',
        # we can send them straight to the enter password page.
        # Else we have to show them the form to request one.
        if params[:reset_password_token].present?
          edit_password_path(resource_name, reset_password_token: params[:reset_password_token])
        else
          new_password_path(resource_name)
        end
      end
    end
  end
end
