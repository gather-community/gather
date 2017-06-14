require 'rails_helper'

RSpec.describe Utils::FakeDataGenerator, type: :model do
  let(:community) { create(:community) }

  it "should run cleanly" do
    described_class.new(community, photos: false).generate
  end
end
