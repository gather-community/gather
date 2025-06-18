# frozen_string_literal: true

require "rails_helper"
require "fileutils"

describe Utils::Generators::RestrictionGenerator do
  let(:community) { create(:community) }
  let(:generator) { described_class.new(community: community) }

  it "should run cleanly" do
    generator.generate_seed_data

    expect(Meals::Restriction.count).to be 9
  end

end
