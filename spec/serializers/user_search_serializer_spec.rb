# frozen_string_literal: true

require "rails_helper"

describe UserSearchSerializer do
  let(:community) { Defaults.community }
  let(:household) { create(:household, community: community) }
  let(:user) { create(:user, household: household, first_name: "Jane", last_name: "Smith") }

  subject(:data) { described_class.new(user).as_json }

  it "includes required fields" do
    expect(data).to include(
      id: user.id,
      kind: "user",
      community_id: community.id,
      first_name: "Jane",
      last_name: "Smith"
    )
  end

  it "includes contact fields" do
    expect(data).to have_key(:email)
    expect(data).to have_key(:home_phone)
    expect(data).to have_key(:mobile_phone)
  end
end
