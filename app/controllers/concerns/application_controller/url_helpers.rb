module Concerns::ApplicationController::UrlHelpers
  extend ActiveSupport::Concern

  included do
    helper_method :home_path, :home_url, :url_in_community, :url_in_home_community
  end

  protected

  def default_url_options
    Settings.url.to_h.slice(:host, :port).tap do |options|
      # Preserve the current subdomain if present.
      options[:host] = "#{current_community.slug}.#{options[:host]}" if current_community
    end
  end

  def url_in_community(community, path = nil)
    host_with_port = ["#{community.slug}.#{Settings.url.host}", Settings.url.port].join(":")
    "#{Settings.url.protocol}://#{host_with_port}#{path}"
  end

  def url_in_home_community(path = nil)
    url_in_community(current_user.community, path)
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
    redirect_to url_in_home_community(home_path)
  end

  def home_path(*args)
    current_user&.inactive? ? inactive_path(*args) : root_path(*args)
  end

  def home_url(*args)
    current_user&.inactive? ? inactive_url(*args) : root_url(*args)
  end

  def sign_in_url
    root_url(host: Settings.url.host, "sign-in": 1)
  end

  def after_sign_out_path_for(user)
    user_signed_out_url(host: Settings.url.host)
  end
end
