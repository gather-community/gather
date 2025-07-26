# frozen_string_literal: true

require "rails_helper"

describe Utils::Generators::GroupGenerator do
  let!(:users) { create_list(:user, 12) }
  let(:generator) { described_class.new(community: Defaults.community) }

  it "generates everybody group and gather.coop domain" do
    generator.generate_seed_data
    expect(Groups::Group.count).to eq(1)
    expect(Groups::Group.first.availability).to eq("everybody")
    expect(Groups::Group.first.memberships).to be_empty
    expect(Domain.count).to eq(1)
    expect(Domain.first.name).to eq("#{Defaults.community.slug}.gather.coop")
    expect(Domain.first.communities).to eq([Defaults.community])
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
