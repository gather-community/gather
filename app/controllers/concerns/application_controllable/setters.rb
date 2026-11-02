# frozen_string_literal: true

module ApplicationControllable::Setters
  extend ActiveSupport::Concern

  protected

  def set_no_cache
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT" # rubocop:disable Gather/HardCodedString
  end

  def render_not_found
    respond_to do |format|
      format.html { render(file: error_page_file("404"), layout: false, status: :not_found) }
      format.any { head :not_found }
    end
  end

  def render_forbidden
    respond_to do |format|
      format.html { render(file: error_page_file("403"), layout: false, status: :forbidden) }
      format.any { head :forbidden }
    end
  end

  # The static error page for the current locale if there is one, else the default locale's.
  # See Gather::ErrorPages.
  def error_page_file(name)
    localized = Rails.public_path.join(Gather::ErrorPages.file_name(name, I18n.locale))
    localized.exist? ? localized : Rails.public_path.join("#{name}.html")
  end
end
