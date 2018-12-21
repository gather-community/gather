# frozen_string_literal: true

require "rails_helper"
require "fileutils"

describe Utils::FakeData::MainGenerator do
  let(:community) { create(:community) }
  let(:cluster) { community.cluster }

  before do
    FileUtils.rm_rf(Rails.root.join("public", "system", "test"))
  end

  it "should run and destroy cleanly" do
    described_class.new(community: community, photos: true).generate

    expect(User.count).to be > 10
    expect(Dir[Rails.root.join("public", "system", "test", "**", "*.jpg")].size).to be > 10

    Utils::DataRemover.new(cluster.id).remove
    community.destroy

    Cluster.cluster_based_models.each do |klass|
      expect(klass.count).to eq(0), "Expected to find no #{klass.name.pluralize}"
    end

    expect(Dir[Rails.root.join("public", "system", "test", "**", "*.*")].size).to eq(0)
  end
end
