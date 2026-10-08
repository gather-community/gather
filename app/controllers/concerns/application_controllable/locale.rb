# frozen_string_literal: true

# Sets the locale for each request from the browser's Accept-Language header. See Gather::Locales.
module ApplicationControllable::Locale
  extend ActiveSupport::Concern

  included do
    # Must be declared after RequestPreprocessing so that authentication and impersonation have happened by
    # the time the feature flag is checked. Everything declared after this, including subclasses' callbacks
    # and the action itself, runs in the chosen locale.
    around_action :switch_locale
  end

  private

  # I18n.with_locale, not I18n.locale=, so the locale can't leak into the next request on this thread.
  def switch_locale(&action)
    # The flag is checked against the person at the keyboard (whose browser sent the header), not the
    # user they're impersonating.
    locale = Gather::Locales.for_request(request.headers["Accept-Language"], user: real_current_user)
    I18n.with_locale(locale, &action)
    response.headers["Vary"] = [response.headers["Vary"].presence, "Accept-Language"].compact.join(", ")
  end
end
