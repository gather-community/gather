# frozen_string_literal: true

require "rails_helper"

describe GDrive::TokenStore do
  let(:community) { Defaults.community }
  let(:config) { create(:gdrive_config, community: community) }
  let(:token_store) { described_class.new(config: config) }

  describe "#store" do
    it "creates a new token" do
      token_store.store("a@example.com", "tokendata")

      token = GDrive::Token.first
      expect(token.gdrive_config_id).to eq(config.id)
      expect(token.google_user_id).to eq("a@example.com")
      expect(token.data).to eq("tokendata")
    end

    it "updates if exists already" do
      token_store.store("a@example.com", "tokendata")
      token_store.store("a@example.com", "tokendata2")

      expect(GDrive::Token.count).to eq(1)
      token = GDrive::Token.first
      expect(token.gdrive_config_id).to eq(config.id)
      expect(token.google_user_id).to eq("a@example.com")
      expect(token.data).to eq("tokendata2")
    end
  end

  describe "#load" do
    before do
      token_store.store("a@example.com", "tokendata")
    end

    it "loads the token" do
      expect(token_store.load("a@example.com")).to eq("tokendata")
    end

    it "returns nil if not found" do
      expect(token_store.load("b@example.com")).to be_nil
    end
  end

  describe "#delete" do
    before do
      token_store.store("a@example.com", "tokendata")
    end

    it "deletes the token" do
      expect(GDrive::Token.count).to eq(1)
      token_store.delete("a@example.com")

      expect(GDrive::Token.count).to eq(0)
      expect(token_store.load("a@example.com")).to be_nil
    end
  end
end
