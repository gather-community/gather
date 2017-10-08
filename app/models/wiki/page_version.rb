module Wiki
  class PageVersion < ActiveRecord::Base
    acts_as_tenant :cluster
    acts_as_wiki_page_version
  end
end
