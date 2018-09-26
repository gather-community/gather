module Concerns::ApplicationController::Setters
  extend ActiveSupport::Concern

  protected

  def set_validation_error_notice(object)
    flash.now[:error] = "Please correct the errors below."
    @full_validation_errors = object.errors.full_messages.join(", ")
  end

  def set_no_cache
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  def render_not_found
    respond_to do |format|
      format.html { render file: Rails.root.join("public/404"), layout: false, status: :not_found }
      format.any { head :not_found }
    end
  end

  def render_forbidden
    respond_to do |format|
      format.html { render file: Rails.root.join("public/403"), layout: false, status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
