module Admin
  class SettingsController < ApplicationController
    def edit
      @community = current_community
      authorize current_community
    end
  end
end
