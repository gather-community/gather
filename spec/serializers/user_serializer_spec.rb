# frozen_string_literal: true

require "rails_helper"

describe UserSerializer do
  let(:community) { create(:community, name: "Foo Community") }
  let(:user) do
    create(:user, first_name: "Jane", last_name: "Doe", email: "jane@example.com", community: community)
  end

  def serialize(**options)
    described_class.new(user.decorate, **options).as_json
  end

  it "sends the id and name by default, but no details" do
    expect(serialize).to eq(id: user.id, name: "Jane Doe")
  end

  it "adds the community and email when details are asked for" do
    expect(serialize(details: true)).to eq(id: user.id, name: "Jane Doe",
      details: "Foo Community · jane@example.com")
  end
end
