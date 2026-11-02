# frozen_string_literal: true

require "rails_helper"

describe People::MemorialSearchSerializer do
  let(:community) { Defaults.community }
  let(:household) { create(:household, community: community) }
  let(:user) { create(:user, household: household) }
  let(:memorial) { create(:memorial, user: user) }

  subject(:data) { described_class.new(memorial).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: memorial.id,
      kind: "memorial",
      community_id: community.id
    )
    expect(data).to have_key(:user_name)
    expect(data).to have_key(:obituary)
    expect(data).to have_key(:messages_body)
  end
end
