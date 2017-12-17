require "rails_helper"

describe Wiki::Page do
  describe "slug" do
    it "gets set automatically" do
      page = create(:wiki_page, title: "An Excéllent Page")
      expect(page.slug).to eq "an-excellent-page"
    end

    it "gets set properly for home page" do
      page = create(:wiki_page, title: "An Excéllent Page", home: true)
      expect(page.slug).to eq "home"
    end

    it "avoids duplicates" do
      page1 = create(:wiki_page, title: "An Excéllent Page")
      page2 = create(:wiki_page, title: "An Excellent Page")
      page3 = create(:wiki_page, title: "An Éxcellent Page")
      expect(page1.slug).to eq "an-excellent-page"
      expect(page2.slug).to eq "an-excellent-page2"
      expect(page3.slug).to eq "an-excellent-page3"
    end

    it "raises validation if title would give result in reserved slug" do
      Wiki::Page::RESERVED_SLUGS.each do |slug|
        page = build(:wiki_page, title: slug.capitalize)
        expect(page).not_to be_valid
        expect(page.errors[:title].join).to match /This title is a special reserved word or phrase./
      end
    end
  end
end
