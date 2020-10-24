# frozen_string_literal: true

require "rails_helper"

describe(People::MemberType) do
  it "has valid factory" do
    create(:member_type)
  end
end
