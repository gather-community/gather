# frozen_string_literal: true

module People
  # Changing password
  class PasswordChangesController < ApplicationController
    skip_before_action :authenticate_user!, only: :strength
    skip_after_action :verify_authorized, only: :strength

    def show
      authorize(current_user, :edit?)
    end

    def update
      authorize(current_user)
      if current_user.update(password_change_params)
        bypass_sign_in(current_user, scope: :user)
        flash[:success] = "Password changed successfully."
        redirect_to(user_path(current_user))
      else
        render(:show)
      end
    end

    def strength
      bits = StrongPassword::StrengthChecker.new(use_dictionary: true).calculate_entropy(params[:password])
      bits = [0, bits].max.round
      category = if bits < User::PASSWORD_MIN_ENTROPY then :weak
                 elsif bits < User::PASSWORD_MIN_ENTROPY + 6 then :good
                 else :excellent
                 end
      render(json: {category: category, bits: bits})
    end

    private

    def password_change_params
      params.require(:user).permit(:password, :password_confirmation).merge(changing_password: true)
    end
  end
end
