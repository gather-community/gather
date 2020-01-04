# frozen_string_literal: true

require "rails_helper"

describe Groups::Membership do
  it "has a valid factory" do
    create(:group_membership)
  end
end
