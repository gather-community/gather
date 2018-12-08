# frozen_string_literal: true

module People
  # Changing password
  class PasswordChangesController < ApplicationController
    def show
      authorize(current_user, :edit?)
    end

    # Check the current password and set the reset token if correct.
    def check
      authorize(current_user, :edit?)
      # If the update succeeds we know the password given matches the current one.
      # We use this method because it handles checking for blanks also.
      if current_user.update_with_password(current_password: params[:user][:current_password])
        # Calling this method resets the reset_password_sent_at column which we check in the update method.
        current_user.reset_reset_password_token!
        redirect_to(edit_people_password_change_path)
      else
        render(:show)
      end
    end

    def edit
      authorize(current_user)
    end

    def update
      authorize(current_user)
      if !current_user.reset_password_period_valid?
        flash[:error] = "Too much time has passed since you entered your current password. Please try again."
        redirect_to(people_password_change_path)
      elsif current_user.update(password_change_params)
        bypass_sign_in(current_user, scope: :user)
        flash[:success] = "Password changed successfully."
        redirect_to(user_path(current_user))
      else
        render(:edit)
      end
    end

    private

    def password_change_params
      params.require(:user).permit(:password, :password_confirmation)
    end
  end
end
