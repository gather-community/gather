module Wiki
  class PagesController < ApplicationController
    acts_as_wiki_pages_controller

    before_action :authorization, except: :all
    before_action :set_community, only: :update

    def all
      authorize sample_page
      @pages = policy_scope(Page).in_community(current_community).by_title
    end

    private

    def sample_page
      Page.new(community: current_community)
    end

    def authorization
      authorize @page
    end

    def set_community
      @page.community = current_community
    end
  end
end
