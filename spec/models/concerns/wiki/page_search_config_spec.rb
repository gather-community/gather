# frozen_string_literal: true

require "rails_helper"

describe Wiki::PageSearchConfig, search: Wiki::Page do
  let(:community) { Defaults.community }
  let(:other_community) { create(:community, cluster: community.cluster) }

  describe "full-text search" do
    let!(:match) { create(:wiki_page, community: community, title: "Solar Panels", content: "Renewable energy") }
    let!(:other_cmty) { create(:wiki_page, community: other_community, title: "Solar Panels Other") }
    let!(:no_match) { create(:wiki_page, community: community, title: "Compost Bins") }

    before { Wiki::Page.__elasticsearch__.refresh_index! }

    it "finds pages matching query in the correct community" do
      parser = Search::QueryParser.new("solar")
      results = Wiki::Page.search(parser.to_es_query(community_id: community.id)).results
      result_slugs = results.map(&:slug)

      expect(result_slugs).to include(match.slug)
      expect(result_slugs).not_to include(other_cmty.slug)
      expect(result_slugs).not_to include(no_match.slug)
    end

    it "searches content as well as title" do
      parser = Search::QueryParser.new("renewable")
      results = Wiki::Page.search(parser.to_es_query(community_id: community.id)).results
      expect(results.map(&:slug)).to include(match.slug)
    end
  end

  describe "title-only search" do
    let!(:title_match) { create(:wiki_page, community: community, title: "Budget 2024", content: "Minutes below") }
    let!(:content_only) { create(:wiki_page, community: community, title: "Other page", content: "Budget notes") }

    before { Wiki::Page.__elasticsearch__.refresh_index! }

    it "restricts to title field when title: prefix used" do
      parser = Search::QueryParser.new("title:budget")
      results = Wiki::Page.search(parser.to_es_query(community_id: community.id)).results
      result_slugs = results.map(&:slug)

      expect(result_slugs).to include(title_match.slug)
      expect(result_slugs).not_to include(content_only.slug)
    end
  end

  describe "index auto-updates" do
    it "indexes new pages on create" do
      page = create(:wiki_page, community: community, title: "New Page About Solar")
      Wiki::Page.__elasticsearch__.refresh_index!

      parser = Search::QueryParser.new("solar")
      results = Wiki::Page.search(parser.to_es_query(community_id: community.id)).results
      expect(results.map(&:slug)).to include(page.slug)
    end

    it "updates index on title change" do
      page = create(:wiki_page, community: community, title: "Old Title")
      Wiki::Page.__elasticsearch__.refresh_index!

      page.update!(title: "Unique Xenon Title")
      Wiki::Page.__elasticsearch__.refresh_index!

      parser = Search::QueryParser.new("xenon")
      results = Wiki::Page.search(parser.to_es_query(community_id: community.id)).results
      expect(results.map(&:slug)).to include(page.slug)
    end
  end
end
