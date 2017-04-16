class ApplicationController < ActionController::Base
  include Pundit, RouteHelpable, Lensable

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :log_full_url
  before_action :set_default_nav_context
  before_action :store_current_location
  before_action :authenticate_user!

  # Verify that controller actions are authorized.
  after_action :verify_authorized,  except: :index, unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index

  helper_method :home_path, :current_community, :multi_community?, :app_version,
    :showable_users_and_children_in

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

  def load_communities_in_cluster
    @communities = Community.by_name
  end

  def multi_community?
    return @multi_community if defined?(@multi_community)
    @multi_community = Community.multiple?
  end

  def set_default_nav_context
    @context = {}
  end

  def nav_context(section, subsection = nil)
    @context = {section: section, subsection: subsection}
  end

  def app_version
    @app_version ||= File.read(Rails.root.join("VERSION"))
  end

  # Users and children related to the given household that the UserPolicy says we can show.
  def showable_users_and_children_in(household)
    UserPolicy.new(current_user, User).filter(household.users_and_children)
  end

  protected

  def default_url_options
    {host: Settings.url.host}
  end

  private

  def log_full_url
    Rails.logger.info("Request URL: #{request.url}")
  end

  def login_url
    root_url(login: 1)
  end

  # Saves the location before loading each page so we can return to the right page after sign in.
  def store_current_location
    # If we're on a devise page, we don't want to store that as the
    # place to return to (for example, we don't want to return to the sign in page after signing in).
    return if devise_controller? || request.fullpath == "/?login=1"
    session["user_return_to"] = request.url
  end

  # Customize the redirect URL if not logged in.
  # The method suggested in the Devise wiki -- using a custom failure app -- caused multiple complications.
  # For instance, it broke `store_current_location` above.
  def authenticate_user!
    if user_signed_in?
      super
    else
      # Important to not redirect in a devise controller because otherwise it will mess up the OAuth flow.
      # The same condition exists in the original implementation.
      redirect_to login_url, notice: I18n.t("devise.failure.unauthenticated") unless devise_controller?
    end
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

  def apex_root_url
    "#{Settings.protocol}://#{Settings.host}"
  end
end
