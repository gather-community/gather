class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  def index
    # Store invite token if provided
    session[:invite_token] = params[:token] if params.has_key?(:token)

    render(layout: false)
  end

  # Used by uptime checker
  def ping
    if dj_pid = (File.read(File.join(Rails.root, "tmp/pids/delayed_job.pid")).to_i rescue nil)
      @dj = (Process.kill(0, dj_pid) && true rescue false)
    else
      @dj = false
    end

    render layout: nil, formats: :text, status: @dj ? 200 : 503
  end
end
