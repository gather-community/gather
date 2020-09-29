# frozen_string_literal: true

require "rails_helper"

describe People::Memorial do
  it "has valid factory" do
    create(:memorial)
  end
end
