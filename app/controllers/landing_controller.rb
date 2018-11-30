# frozen_string_literal: true

# Controls landing, ping, privacy policy, and other assorted pages.
class LandingController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    skip_policy_scope
    save_invite_token_in_session
    render(layout: false)
  end

  # Used by uptime checker
  def ping
    skip_authorization
    @status = SystemStatus.new
    render(layout: nil, formats: :text, status: @status.ok? ? 200 : 503)
  end

  def signed_out
    skip_authorization
    if user_signed_in?
      redirect_to(root_path)
    else
      flash.delete(:notice)
      render(layout: false)
    end
  end

  def public_static
    skip_authorization
    render_not_found unless %w[privacy-policy markdown].include?(params[:page])
    render(params[:page].tr("-", "_"))
  end

  private

  # Sets a given token in the session so that the ID returned in the callback can be associated
  # with the user's Gather account.
  def save_invite_token_in_session
    session[:invite_token] = params[:token] if params.key?(:token)
  end
end
