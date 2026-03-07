# frozen_string_literal: true

require "rails_helper"

describe Search::QueryParser do
  describe "#blank?" do
    it "is true for empty string" do
      expect(described_class.new("")).to be_blank
    end

    it "is true for only type: filter" do
      expect(described_class.new("type:doc")).to be_blank
    end

    it "is false for bare terms" do
      expect(described_class.new("solar panels")).not_to be_blank
    end

    it "is false for title: term" do
      expect(described_class.new("title:minutes")).not_to be_blank
    end
  end

  describe "parsing bare terms" do
    subject(:parser) { described_class.new("solar panels energy") }

    it "collects all words as full_text_terms" do
      expect(parser.full_text_terms).to eq(%w[solar panels energy])
    end

    it "leaves title_terms empty" do
      expect(parser.title_terms).to be_empty
    end
  end

  describe "parsing quoted phrases" do
    subject(:parser) { described_class.new('"solar panels" energy') }

    it "includes the phrase as a single full_text_term" do
      expect(parser.full_text_terms).to eq(["solar panels", "energy"])
    end
  end

  describe "parsing title: prefix" do
    subject(:parser) { described_class.new("title:minutes 2024") }

    it "extracts title term" do
      expect(parser.title_terms).to eq(["minutes"])
    end

    it "keeps remaining word as full_text_term" do
      expect(parser.full_text_terms).to eq(["2024"])
    end
  end

  describe "parsing title: with quoted phrase" do
    subject(:parser) { described_class.new('title:"budget report"') }

    it "extracts quoted title term" do
      expect(parser.title_terms).to eq(["budget report"])
    end

    it "leaves full_text_terms empty" do
      expect(parser.full_text_terms).to be_empty
    end
  end

  describe "parsing type: filter" do
    subject(:parser) { described_class.new("minutes type:sheet") }

    it "extracts type_filter" do
      expect(parser.type_filter).to eq("sheet")
    end

    it "leaves type: out of full_text_terms" do
      expect(parser.full_text_terms).to eq(["minutes"])
    end
  end

  describe "#to_gdrive_q" do
    it "includes trashed filter" do
      parser = described_class.new("report")
      expect(parser.to_gdrive_q).to include("trashed = false")
    end

    it "adds fullText clause for bare terms" do
      parser = described_class.new("solar panels")
      q = parser.to_gdrive_q
      expect(q).to include("fullText contains 'solar'")
      expect(q).to include("fullText contains 'panels'")
    end

    it "adds name clause for title terms" do
      parser = described_class.new("title:minutes")
      expect(parser.to_gdrive_q).to include("name contains 'minutes'")
    end

    it "adds mimeType clause for known type filter" do
      parser = described_class.new("type:sheet")
      expect(parser.to_gdrive_q).to include("mimeType = 'application/vnd.google-apps.spreadsheet'")
    end

    it "ignores unknown type filter" do
      parser = described_class.new("type:unknown report")
      expect(parser.to_gdrive_q).not_to include("mimeType")
    end

    it "escapes single quotes in terms" do
      parser = described_class.new("it's")
      expect(parser.to_gdrive_q).to include("fullText contains 'it\\'s'")
    end
  end

  describe "#to_es_query" do
    let(:community_id) { 42 }

    it "includes community_id filter" do
      parser = described_class.new("solar")
      query = parser.to_es_query(community_id: community_id)
      expect(query.dig(:query, :bool, :filter)).to include({term: {community_id: 42}})
    end

    it "uses multi_match for full_text_terms" do
      parser = described_class.new("solar panels")
      must = parser.to_es_query(community_id: community_id).dig(:query, :bool, :must)
      expect(must).to include(a_hash_including(multi_match: a_hash_including(query: "solar panels")))
    end

    it "adds match on title for title_terms" do
      parser = described_class.new("title:minutes")
      must = parser.to_es_query(community_id: community_id).dig(:query, :bool, :must)
      expect(must).to include({match: {title: "minutes"}})
    end

    it "falls back to match_all when no terms" do
      parser = described_class.new("type:doc")
      must = parser.to_es_query(community_id: community_id).dig(:query, :bool, :must)
      expect(must).to include({match_all: {}})
    end

    it "includes highlight config" do
      parser = described_class.new("solar")
      query = parser.to_es_query(community_id: community_id)
      expect(query).to have_key(:highlight)
    end
  end
end
