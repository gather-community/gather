# frozen_string_literal: true

require "rails_helper"

describe GDrive::TokenStore do
  let(:community) { Defaults.community }

  describe "#store" do
    it "updates the token" do
      config = create(:gdrive_main_config, community: community)
      described_class.new.store(community.id.to_s, "atoken")
      expect(config.reload.token).to eq("atoken")
    end

    it "errors if not found" do
      expect do
        described_class.new.store(community.id.to_s, "atoken")
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#load" do
    let!(:config) { create(:gdrive_main_config, community: community, token: "atoken") }

    it "loads the token" do
      expect(described_class.new.load(community.id.to_s)).to eq("atoken")
    end

    it "returns nil if not found" do
      expect(described_class.new.load("7397349148319")).to be_nil
    end
  end

  describe "#delete" do
    let!(:config) { create(:gdrive_main_config, community: community, token: "atoken") }

    it "deletes the config" do
      described_class.new.delete(community.id.to_s)
      expect { config.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
