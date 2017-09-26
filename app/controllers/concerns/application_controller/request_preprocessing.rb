# Handles the processing of requests before they reach the controller action method itself.
# All global before_actions should go here.
# The basic flow is:
#
# - Authenticate via token if action was prepended.
# - Check subdomain validity and set current_community.
# - Store the requested URL in case auth fails.
# - Authenticate user via session unless already authenticated.
# - Redirect to an appropriate subdomain or 404 if subdomain missing and this filter not skipped.
# - Ensure the current_user has access to the current_community if both set.
# - Set the current tenant (cluster) based on the current community.
module Concerns::ApplicationController::RequestPreprocessing
  extend ActiveSupport::Concern

  included do
    # This indicates to acts_as_tenant that we're planning to set the tenant via a before_action
    # The actual before_action (set_tenant) is called below.
    set_current_tenant_through_filter

    before_action :log_full_url
    before_action :set_default_nav_context
    before_action :check_subdomain_validity
    before_action :store_current_location
    before_action :authenticate_user!
    before_action :prepare_exception_notifier
    before_action :ensure_subdomain
    before_action :check_community_permissions
    before_action :set_tenant
    before_action :set_time_zone

    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
  end

  private

  # Currently we are only checking for calendar_token, but could add others later.
  def authenticate_user_from_token!
    if params[:calendar_token] && user = User.find_by_calendar_token(params[:calendar_token])
      # We are passing store false, so the user is not
      # actually stored in the session and a token is needed for every request.
      sign_in user, store: false
    else
      render_error_page(:forbidden)
    end
  end

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
    return if devise_controller? || request.fullpath == "/?sign-in=1" || request.fullpath =~ %r{\A/\?token=.+}
    session["user_return_to"] = request.url
  end

  # Customize the redirect URL if not signed in.
  # The method suggested in the Devise wiki -- using a custom failure app -- caused multiple complications.
  # For instance, it broke `store_current_location` above.
  def authenticate_user!
    if user_signed_in?
      super
    elsif request.format == :ics
      # Dont redirect calendar requests to sign in because that makes no sense.
      # Auth with token already fails hard with 403 but if someone points their calendar app at a bad URL
      # we get errors if we redirect.
      render_error_page(:forbidden)
    else
      # Important to not redirect in a devise controller because otherwise it will mess up the OAuth flow.
      # The same condition exists in the original implementation.
      redirect_to sign_in_url, notice: I18n.t("devise.failure.unauthenticated") unless devise_controller?
    end
  end

  def prepare_exception_notifier
    data = {
      community: {
        id: current_community.try(:id),
        name: current_community.try(:name)
      }
    }

    if user_signed_in?
      data[:user] = {
        id: current_user.id,
        name: current_user.name,
        email: current_user.email,
        google_email: current_user.google_email
      }
    end

    request.env["exception_notifier.exception_data"] = data
  end

  # Redirects requests to the appropriate subdomain if one is needed but missing.
  # The assumption here is that all authenticated pages that do not skip this action require a subdomain.
  # But not all unauthenticated pages do. If no current_user is set by now and we have not redirected,
  # this must be an unauthenticated page, so we don't need to do anything
  # if current_user is not present or if this is a Devise controller.
  def ensure_subdomain
    return if devise_controller? || current_user.nil? || subdomain.present?
    if community = community_for_route
      host = "#{community.slug}.#{Settings.url.host}"
      url_builder = Settings.url.protocol == "https" ? URI::HTTPS : URI::HTTP
      url_params = Settings.url.to_h.merge(host: host)
      url_params[:path], url_params[:query] = request.fullpath.split("?")
      redirect_to url_builder.build(url_params).to_s
    else
      render_error_page(:not_found)
    end
  end

  # Checks that the subdomain's community is accessible by the user.
  # Does nothing if user is not present or current_community is not present.
  # Renders 403 if community not permitted.
  def check_community_permissions
    return unless current_user.present? && current_community.present?
    render_error_page(:forbidden) unless policy(current_community).show?
  end

  # Set the current tenant (cluster). If current_community is not set, does nothing.
  # Assumes that current_community would be set by now if one is required for this route.
  # If a tenant is not set and query is attempted on a tenant-scoped model, an error will result.
  def set_tenant
    return unless current_community.present?
    set_current_tenant(current_community.cluster)

    # Scoping is turned off temporarily in a rack middleware to prevent NoTenantSet errors in preprocessing.
    # We turn it back on here.
    ActsAsTenant.unscoped = false
  end

  def set_time_zone
    Time.zone = current_community.settings.time_zone if current_community
  end

  # Redirects to inactive page when user is inactive.
  def handle_unauthorized(exception)
    if current_user.try(:inactive?)
      redirect_to(inactive_path)
    else
      raise exception
    end
  end
end
