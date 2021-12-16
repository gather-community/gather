# frozen_string_literal: true

module Calendars
  module Exportable
    extend ActiveSupport::Concern

    def authenticate_user_from_token!
      if params[:calendar_token] && (user = User.find_by(calendar_token: params[:calendar_token]))
        # We are passing store false, so the user is not
        # actually stored in the session and a token is needed for every request.
        sign_in(user, store: false)
      else
        render_error_page(:unauthorized)
      end
    end

    def send_calendar_data(export)
      send_data(export.generate, filename: "#{export_file_basename}.ics", type: "text/calendar")
    end

    def handle_calendar_error
      skip_authorization # Auth may not have been performed yet but that's OK b/c we're erroring.
      render(plain: "Invalid calendar type", status: :not_found)
    end
  end
end
