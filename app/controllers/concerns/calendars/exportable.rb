# frozen_string_literal: true

module Calendars
  module Exportable
    extend ActiveSupport::Concern

    def event_date_range
      (Time.current - 1.year)..(Time.current + 1.year)
    end

    def authenticate_user_from_calendar_token!
      if params[:token] && (user = User.find_by(calendar_token: params[:token]))
        # We are passing store false, so the user is not
        # actually stored in the session and a token is needed for every request.
        sign_in(user, store: false)
      else
        render_error_page(:unauthorized)
      end
    end

    def send_calendar_data(calendar_name, eventlets)
      host = "#{current_community.subdomain}.#{Settings.url.host}"
      url_options = Settings.url.to_h.slice(:port, :protocol).merge(host: host)
      generator = IcalGenerator.new(calendar_name: calendar_name, eventlets: eventlets,
                                     url_options: url_options)
      send_data(generator.generate, filename: "#{export_file_basename}.ics", type: "text/calendar")
    end

    private

    # Calendar apps fetch the feeds without a person's browser behind the request, so a feed isn't in
    # whatever Accept-Language the calendar app sends. It's in the language of whoever it belongs to: a
    # personalized feed in its token user's, a community's feed in the community's. Including controllers
    # use this in place of switch_locale for their feed actions.
    def with_feed_locale(&block)
      locale = if action_name == "personalized"
        Gather::Locales.for_user(current_user)
      else
        Gather::Locales.for_community(current_community)
      end
      I18n.with_locale(locale, &block)
    end
  end
end
