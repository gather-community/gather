# frozen_string_literal: true

require "rails_helper"

describe People::MemorialMessage do
  it "has valid factory" do
    create(:memorial_message)
  end
end
