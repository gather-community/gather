module Wiki
  class PageVersion < ActiveRecord::Base
    acts_as_wiki_page_version
  end
end
