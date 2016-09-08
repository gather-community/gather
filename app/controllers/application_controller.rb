class ApplicationController < ActionController::Base
  include Pundit, RouteHelpable

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :store_current_location
  before_action :authenticate_user!

  # Verify that controller actions are authorized.
  after_action :verify_authorized,  except: :index, unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index

  helper_method :home_path, :current_community

  def set_validation_error_notice
    flash.now[:error] = "Please correct the errors below."
  end

  def redirect_to_home
    redirect_to home_path
  end

  def home_path
    current_user.try(:inactive?) ? inactive_path : root_path
  end

  def set_no_cache
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  def current_community
    current_user.try(:community)
  end

  def default_serializer_options
    { root: false }
  end

  private

  # Saves the location before loading each page so we can return to the right page after sign in.
  def store_current_location
    # If we're on a devise page, we don't want to store that as the
    # place to return to (for example, we don't want to return to the sign in page
    # after signing in).
    # Also since the root path is shown if authentication fails, we don't want to store that either.
    return if devise_controller? || request.fullpath == '/'
    store_location_for(:user, request.url)
  end
end
