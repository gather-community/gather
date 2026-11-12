# frozen_string_literal: true

require "rails_helper"

describe ApplicationRecord do
  describe ".matching_word_starts" do
    let!(:smith) { create(:household, name: "Smith-Jones") }
    let!(:zoe) { create(:household, name: "Zoë O'Brien") }
    let!(:other) { create(:household, name: "Garcia") }

    def search(query)
      Household.matching_word_starts("households.name", query)
    end

    it "requires each word to start a word of the text, in any order and any case" do
      expect(search("jon SMI")).to contain_exactly(smith)
      expect(search("smi xyz")).to be_empty
      expect(search("ith")).to be_empty
    end

    it "treats punctuation as a word break, in the text and in the query" do
      expect(search("jones")).to contain_exactly(smith)
      expect(search("brien")).to contain_exactly(zoe)
      expect(search("o'bri")).to contain_exactly(zoe)
    end

    it "ignores accents on either side" do
      expect(search("zoe")).to contain_exactly(zoe)
      expect(search("ZOË")).to contain_exactly(zoe)
    end

    it "matches everything for a blank query" do
      expect(search(" ")).to contain_exactly(smith, zoe, other)
    end

    it "matches nothing for a query with no words, and treats LIKE wildcards literally" do
      expect(search("%%")).to be_empty
      expect(search("s%h")).to be_empty
    end

    it "combines with OR" do
      expect(search("garcia").or(search("zoe"))).to contain_exactly(zoe, other)
    end
  end

  describe "tenant validation of associations" do
    let(:other_cluster) { create(:cluster) }
    let(:other_community) { ActsAsTenant.with_tenant(other_cluster) { create(:community) } }
    let(:outside_user) do
      ActsAsTenant.with_tenant(other_cluster) { create(:user, community: other_community) }
    end

    it "allows an association to a user from another cluster" do
      page = build(:wiki_page, creator: outside_user, updater: outside_user)
      expect(page).to be_valid
    end

    it "rejects an association to another kind of record from another cluster" do
      page = build(:wiki_page, community: other_community)
      expect(page).not_to be_valid
      expect(page.errors.details[:community_id]).to include(error: :"acts_as_tenant.association_invalid")
    end
  end
end
