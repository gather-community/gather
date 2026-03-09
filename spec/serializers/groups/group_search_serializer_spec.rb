# frozen_string_literal: true

require "rails_helper"

describe Groups::GroupSearchSerializer do
  let(:community) { Defaults.community }
  let(:group) { create(:group, communities: [community], name: "Solar Committee") }

  subject(:data) { described_class.new(group).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: group.id,
      kind: "group",
      name: "Solar Committee"
    )
    expect(data[:community_ids]).to include(community.id)
  end
end
