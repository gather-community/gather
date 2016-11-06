class ApplicationController < ActionController::Base
  include Pundit, RouteHelpable, Lensable

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :store_current_location
  before_action :authenticate_user!

  # Verify that controller actions are authorized.
  after_action :verify_authorized,  except: :index, unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index

  helper_method :home_path, :current_community, :multi_community?

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  private

  # Redirects to inactive page when user is inactive.
  def handle_unauthorized(exception)
    if current_user.try(:inactive?)
      redirect_to(inactive_path)
    else
      raise exception
    end
  end

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

  def load_communities
    @communities = Community.by_name
  end

  def multi_community?
    return @multi_community if defined?(@multi_community)
    @multi_community = Community.multiple?
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

  # Currently we are only checking for calendar_token, but could add others later.
  def authenticate_user_from_token!
    if params[:calendar_token] && user = User.find_by_calendar_token(params[:calendar_token])
      # We are passing store false, so the user is not
      # actually stored in the session and a token is needed for every request.
      sign_in user, store: false
    end
  end

  def after_sign_out_path_for(user)
    logged_out_path
  end
end
