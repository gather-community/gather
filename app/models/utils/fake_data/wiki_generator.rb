module Utils
  module FakeData
    class WikiGenerator < Generator
      attr_accessor :community

      def initialize(community:)
        self.community = community
      end

      def generate
        creator = User.active.to_a.sample
        pages = FactoryGirl.create_list(:wiki_page, 2, community: community, creator: creator)
        main_content = Faker::Lorem.sentence << ":\n\n* [[#{pages[0].title}]]\n* [[#{pages[1].title}]]"
        FactoryGirl.create(:wiki_page, community: community, creator: creator,
          path: nil, content: main_content)
      end
    end
  end
end
