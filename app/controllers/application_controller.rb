class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Makes sure authorization is performed in each controller. (CanCan method)
  check_authorization unless: :devise_controller?

  before_action :authenticate_user!

  def set_validation_error_notice
    flash.now[:error] = "Please correct the errors below."
  end
end
