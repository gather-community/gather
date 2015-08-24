class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  def index
    render(layout: "home")
  end
end
