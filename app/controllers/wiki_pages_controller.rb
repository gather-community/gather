class WikiPagesController < ApplicationController

  acts_as_wiki_pages_controller

  before_action :skip_authorization

end
