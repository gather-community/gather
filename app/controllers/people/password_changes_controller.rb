# frozen_string_literal: true

module People
  # Changing password
  class PasswordChangesController < ApplicationController
    def show
      authorize(current_user, :edit?)
    end

    def update
      authorize(current_user)
      if current_user.update_with_password(password_change_params)
        bypass_sign_in(current_user, scope: :user)
        flash[:success] = "Password changed successfully."
        redirect_to(user_path(current_user))
      else
        render(:show)
      end
    end

    private

    def password_change_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
  end
end
