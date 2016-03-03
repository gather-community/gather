class HomeController < ApplicationController
  def inactive
    if current_user.active?
      skip_authorization
      redirect_to root_path
    else
      authorize :homepage
    end
  end
end
