require 'rails_helper'

RSpec.describe Utils::FakeData::MainGenerator, type: :model do
  let(:community) { create(:community) }

  it "should run cleanly" do
    described_class.new(community: community, photos: false).generate
  end
end
