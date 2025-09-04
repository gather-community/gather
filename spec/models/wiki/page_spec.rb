# frozen_string_literal: true

# == Schema Information
#
# Table name: wiki_pages
#
#  id           :integer          not null, primary key
#  cluster_id   :integer          not null
#  community_id :integer          not null
#  content      :text
#  created_at   :datetime         not null
#  creator_id   :integer
#  data_source  :text
#  editable_by  :string           default("everyone"), not null
#  role         :string
#  slug         :string           not null
#  title        :string           not null
#  updated_at   :datetime         not null
#  updater_id   :integer
#
require "rails_helper"

describe Wiki::Page do
  describe "validation" do
    describe "template errors" do
      let(:error) { nil }
      let(:page) { build(:wiki_page, data_source: data_source) }

      before do
        allow(page).to receive(:decorate).and_return(double(template_error: error))
      end

      context "with no data source" do
        let(:data_source) { nil }

        it { expect(page).to be_valid }
      end

      context "with data source" do
        let(:data_source) { "http://example.com" }

        context "with no template error" do
          it { expect(page).to be_valid }
        end

        context "with template error" do
          let(:error) { "Template Error: Big bad error" }

          it "sets error" do
            expect(page).not_to be_valid
            expect(page.errors[:content].join).to eq("Template Error: Big bad error")
          end
        end
      end
    end

    describe "updating sample page" do
      let(:page) { create(:wiki_page, role: "sample") }

      it "is not allowed" do
        page.title = "Something New"
        expect(page).not_to be_valid
        expect(page.errors[:base].join).to match("not editable")
      end
    end
  end

  describe "slug" do
    it "gets set automatically" do
      page = create(:wiki_page, title: "An Excéllent Page")
      expect(page.slug).to eq("an-excellent-page")
    end

    it "stays correct on update" do
      page = create(:wiki_page, title: "An Excellent Page")
      page.update!(content: "Some new content")
      expect(page.slug).to eq("an-excellent-page")
    end

    it "gets set properly for home and sample pages" do
      page = create(:wiki_page, title: "An Excéllent Page", role: "home")
      expect(page.slug).to eq("home")
      page = create(:wiki_page, title: "A Sample Page", role: "sample")
      expect(page.slug).to eq("sample")
    end

    it "avoids duplicates" do
      page1 = create(:wiki_page, title: "An Excéllent Page")
      page2 = create(:wiki_page, title: "An Excellent Page")
      page3 = create(:wiki_page, title: "An Éxcellent Page")
      expect(page1.slug).to eq("an-excellent-page")
      expect(page2.slug).to eq("an-excellent-page2")
      expect(page3.slug).to eq("an-excellent-page3")
    end

    it "raises validation if title would give result in reserved slug" do
      Wiki::Page::RESERVED_SLUGS.each do |slug|
        page = build(:wiki_page, title: slug.capitalize)
        expect(page).not_to be_valid
        expect(page.errors[:title].join).to match(/This title is a special reserved word or phrase./)
      end
    end
  end

  describe "saving versions" do
    let!(:page) { create(:wiki_page) }

    context "with content change" do
      it "saves new version" do
        expect { page.update!(content: "Some new content") }.to change { Wiki::PageVersion.count }.by(1)
      end
    end

    context "with comment" do
      it "saves new version" do
        expect { page.update!(comment: "Some comment") }.to change { Wiki::PageVersion.count }.by(1)
      end
    end

    context "with title change" do
      it "saves new version" do
        expect { page.update!(title: "New title") }.to change { Wiki::PageVersion.count }.by(1)
      end
    end

    context "without title, content, or comment change" do
      it "doesn't save new version" do
        expect { page.update!(editable_by: "wikiist") }.to change { Wiki::PageVersion.count }.by(0)
        expect { page.update!(data_source: "http://foo.com") }.to change { Wiki::PageVersion.count }.by(0)
      end
    end
  end
end
