require 'rails_helper'
require 'fileutils'

RSpec.describe Utils::FakeData::MainGenerator, type: :model do
  let(:community) { create(:community) }
  let(:cluster) { community.cluster }

  before do
    FileUtils.rm_rf("#{Rails.root}/public/system/test")
  end

  it "should run and destroy cleanly" do
    described_class.new(community: community, photos: true).generate

    expect(User.count).to be > 10
    expect(Dir["#{Rails.root}/public/system/test/**/*.jpg"].size).to be > 10

    cluster.reload.destroy

    Cluster::CLUSTER_BASED_MODELS.each do |klass|
      expect(klass.count).to eq(0), "Expected to find no #{klass.name}s"
    end

    expect(Dir["#{Rails.root}/public/system/test/**/*.*"].size).to eq 0
  end
end
