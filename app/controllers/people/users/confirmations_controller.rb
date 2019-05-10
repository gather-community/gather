# frozen_string_literal: true

module People
  module Users
    # Handles reconfirming email, but not initial confirmation, as that is handled through the sign-in
    # invitation process.
    class ConfirmationsController < Devise::ConfirmationsController
      protected

      def after_confirmation_path_for(resource_name, resource)
        if signed_in?(resource_name)
          # Devise sets a flash[:notice] which we will use as-is on the user page.
          user_path(resource)
        else
          # In this case we want to add a bit more context.
          flash[:notice] << " Please sign in to use Gather."
          root_path
        end
      end
    end
  end
end
