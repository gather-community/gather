module Concerns::ApplicationController::UrlHelpers
  extend ActiveSupport::Concern

  included do
    helper_method :home_path, :build_url_with
  end

  protected

  def default_url_options
    Settings.url.to_h.slice(:host, :port)
  end

  def build_url_with(subdomain:, path: nil)
    host_with_port = ["#{subdomain}.#{Settings.url.host}", Settings.url.port].join(":")
    "#{Settings.url.protocol}://#{host_with_port}#{path}"
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

  # Returns the appropriate community for the requested action in case subdomain not given.
  # Should only return a community for routes that are likely to appear in links in the wild.
  # Used in subdomain redirection.
  # Should be overridden by subclasses.
  def community_for_route
    nil
  end

  def redirect_to_home
    redirect_to home_path
  end

  def home_path
    current_user.try(:inactive?) ? inactive_path : root_path
  end

  def sign_in_url
    root_url("sign-in": 1)
  end

  def after_sign_out_path_for(user)
    signed_out_url(host: Settings.url.host)
  end
end
