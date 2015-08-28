class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  def index
    # Store invite token if provided
    session[:invite_token] = params[:token] if params.has_key?(:token)

    render(layout: false)
  end
end
