class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Makes sure authorization is performed in each controller. (CanCan method)
  check_authorization unless: :devise_controller?

  before_action :mailer_set_url_options
  before_action :authenticate_user!

  rescue_from(Exception, with: :notify_error)

  # mailer is for some reason too stupid to figure these out on its own
  def mailer_set_url_options
    # copy options from the above method, and add a host option b/c mailer is especially stupid
    default_url_options.merge(host: Rails.configuration.x.host).each_pair do |k,v|
      ActionMailer::Base.default_url_options[k] = v
    end
  end

  def set_validation_error_notice
    flash[:error] = "Please correct the errors below."
  end

  # Notifies webmasters of error
  def notify_error(exception)
    if %w(production staging development).include?(Rails.env)
      begin
        AdminMailer.error(
          exception: exception,
          headers: request.headers,
          session: session.to_hash,
          params: params,
          env: request.env,
          user: current_user
        ).deliver_now
      rescue
        logger.error("ERROR SENDING ADMIN ERROR NOTIFICATION: #{$!}")
      end
    end

    # still show error page
    raise exception
  end
end
