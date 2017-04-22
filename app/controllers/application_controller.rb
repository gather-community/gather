class ApplicationController < ActionController::Base
  include Pundit, RouteHelpable, Lensable

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :log_full_url
  before_action :set_default_nav_context
  before_action :check_subdomain_validity
  before_action :store_current_location
  before_action :authenticate_user!
  before_action :ensure_subdomain
  before_action :check_community_permissions

  # Verify that controller actions are authorized.
  after_action :verify_authorized,  except: :index, unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index

  attr_accessor :current_community

  helper_method :home_path, :current_community, :multi_community?, :app_version,
    :showable_users_and_children_in

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  protected

  def default_url_options
    Settings.url.to_h.slice(:host, :port)
  end

  private

  def log_full_url
    Rails.logger.info("Request URL: #{request.url}")
  end

  def set_default_nav_context
    @context = {}
  end

  # Checks that the subdomain's community exists and sets current_community.
  # Does nothing if subdomain is not present.
  # Renders 404 if community not found.
  def check_subdomain_validity
    return unless subdomain.present?
    self.current_community = Community.find_by(slug: subdomain)
    render_error_page(:not_found) if current_community.nil?
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

  # Redirects requests to the appropriate subdomain if one is needed but missing.
  # The assumption here is that all authenticated pages that do not skip this action require a subdomain.
  # But not all unauthenticated pages do. If no current_user is set by now and we have not redirected,
  # this must be an unauthenticated page, so we don't need to do anything
  # if current_user is not present or if this is a Devise controller.
  def ensure_subdomain
    return if devise_controller? || current_user.nil? || subdomain.present?
    host = "#{current_user.community.slug}.#{Settings.url.host}"
    redirect_to URI::HTTP.build(Settings.url.to_h.merge(host: host, path: request.fullpath)).to_s
  end

  # Checks that the subdomain's community is accessible by the user.
  # Does nothing if user is not present or current_community is not present.
  # Renders 403 if community not permitted.
  def check_community_permissions
    return unless current_user.present? && current_community.present?
    render_error_page(:forbidden) unless policy(current_community).show?
  end

  def subdomain
    @subdomain ||= request.subdomain.try(:sub, /\.?gather\z/, "")
  end

  def render_error_page(status)
    respond_to do |format|
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
      format.html { render file: "#{Rails.root}/public/#{code}", layout: false, status: status }
      format.any  { head status }
    end
  end

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

  def login_url
    root_url(login: 1)
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
