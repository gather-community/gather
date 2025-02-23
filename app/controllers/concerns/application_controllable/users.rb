# frozen_string_literal: true

module ApplicationControllable::Users
  extend ActiveSupport::Concern

  included do
    attr_reader :impersonated_user

    helper_method :current_user, :real_current_user, :impersonated_user
  end

  def real_current_user
    @real_current_user || current_user
  end

  # alias_method :devise_current_user, :current_user

  # def current_user(ignore_impersonation: false)
  #   if session[:impersonating_id] && !ignore_impersonation
  #     impersonated_user
  #   else
  #     devise_current_user
  #   end
  # end

  # def real_current_user
  #   current_user#(ignore_impersonation: true)
  # end
  #
  # def impersonated_user
  #   return @impersonated_user if defined?(@impersonated_user)
  #   @impersonated_user = User.find_by(id: session[:impersonating_id])
  # end
end
