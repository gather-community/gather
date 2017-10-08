module Wiki
  class PagesController < ApplicationController
    acts_as_wiki_pages_controller

    before_action :skip_authorization
    before_action :set_community, only: :update

    private

    def set_community
      @page.community = current_community
    end
  end
end
