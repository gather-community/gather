class ApplicationController < ActionController::Base
  include Pundit

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :authenticate_user!

  # Verify that controller actions are authorized.
  after_action :verify_authorized,  except: :index
  after_action :verify_policy_scoped, only: :index

  def set_validation_error_notice
    flash.now[:error] = "Please correct the errors below."
  end
end
