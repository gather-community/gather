class LandingController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    skip_policy_scope

    # Store invite token if provided
    session[:invite_token] = params[:token] if params.has_key?(:token)

    render(layout: false)
  end

  # Used by uptime checker
  def ping
    skip_authorization
    if dj_pid = (File.read(File.join(Rails.root, "tmp/pids/delayed_job.pid")).to_i rescue nil)
      @dj = (Process.kill(0, dj_pid) && true rescue false)
    else
      @dj = false
    end

    render layout: nil, formats: :text, status: @dj ? 200 : 503
  end

  def logged_out
    skip_authorization
    if user_signed_in?
      redirect_to root_path
    else
      flash.delete(:notice)
      render(layout: false)
    end
  end
end
