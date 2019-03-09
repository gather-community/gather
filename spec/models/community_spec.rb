# frozen_string_literal: true

require "rails_helper"

describe Community do
  let(:community) { create(:community) }

  it "generates a calendar token on create" do
    expect(community.calendar_token).to match(/\A[0-9a-zA-Z_-]{20}\z/)
  end
end
