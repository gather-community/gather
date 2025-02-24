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
      password = params[:password]
      checker = StrongPassword::StrengthChecker.new(**User::PASSWORD_STRENGTH_CHECKER_OPTIONS)
      if checker.is_weak?(password)
        category = :weak
        bits = checker.calculate_entropy(password)
      else
        # Check again with a more stringent checker.
        checker = StrongPassword::StrengthChecker.new(**User::PASSWORD_STRENGTH_CHECKER_OPTIONS,
min_entropy: User::PASSWORD_MIN_ENTROPY + 6)
        category = checker.is_weak?(password) ? :good : :excellent
        bits = checker.calculate_entropy(password)
      end

      Rails.logger.info("PASSWORD-STRENGTH-CHECK-LINE", category: category, bits: bits)

      render(json: {category: category, bits: bits})
    end

    private

    def password_change_params
      params.require(:user).permit(:password, :password_confirmation).merge(changing_password: true)
    end
  end
end
