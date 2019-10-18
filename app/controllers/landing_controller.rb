# frozen_string_literal: true

# Controls landing, ping, privacy policy, and other assorted pages.
class LandingController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :ensure_apex_domain, only: :index

  # We have to be on apex domain for index page because otherwise the CSRF system doesn't work
  # with the sign-in-with-google link because it's a cross-domain request.
  # The sign-in-with-google flow has to happen on the apex domain.

  def index
    if (@invite_token = params[:token])
      flash.now[:notice] = "Welcome to Gather! Please choose a sign in option below."
    end
    render(layout: false)
  end

  # Used by uptime checker
  def ping
    @status = SystemStatus.new
    render(layout: nil, formats: :text, status: @status.ok? ? 200 : 503)
  end

  def signed_out
    if user_signed_in?
      redirect_to(root_path)
    else
      flash.delete(:notice)
      render(layout: false)
    end
  end

  def public_static
    render_not_found unless %w[privacy-policy markdown].include?(params[:page])
    render(params[:page].tr("-", "_"))
  end
end
