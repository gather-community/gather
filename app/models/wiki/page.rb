module Wiki
  class Page < ActiveRecord::Base
    acts_as_tenant :cluster
    acts_as_wiki_page

    belongs_to :community
    belongs_to :creator, class_name: "User"
    belongs_to :updator, class_name: "User"
  end
end
