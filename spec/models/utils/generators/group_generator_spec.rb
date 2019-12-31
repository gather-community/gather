# frozen_string_literal: true

require "rails_helper"

describe Utils::Generators::GroupGenerator do
  let(:community) { create(:community) }
  let!(:users) { create_list(:user, 12) }
  let(:generator) { described_class.new(community: community) }

  it "generates everyone group" do
    generator.generate_everybody_group
    expect(Groups::Group.count).to eq(1)
    expect(Groups::Group.first.availability).to eq("everybody")
    expect(Groups::Group.first.memberships).to be_empty
  end

  it "generates samples" do
    generator.generate_samples
    expect(Groups::Group.count).to eq(3)

    everybody = Groups::Group.all.detect(&:everybody?)
    expect(everybody.managers.size).to eq(1)
    expect(everybody.opt_outs.size).to eq(2)

    ctte = Groups::Group.all.detect(&:closed?)
    expect(ctte.managers.size).to eq(1)
    expect(ctte.joiners.size).to eq(3)

    knitting = Groups::Group.all.detect(&:open?)
    expect(knitting.managers.size).to eq(2)
    expect(knitting.joiners.size).to eq(3)
  end
end
