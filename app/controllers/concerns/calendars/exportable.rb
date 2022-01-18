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

    def send_calendar_data(calendar_name, events)
      host = "#{current_community.subdomain}.#{Settings.url.host}"
      url_options = Settings.url.to_h.slice(:port, :protocol).merge(host: host)
      generator = IcalGenerator.new(calendar_name: calendar_name, events: events,
                                    url_options: url_options)
      send_data(generator.generate, filename: "#{export_file_basename}.ics", type: "text/calendar")
    end
  end
end
