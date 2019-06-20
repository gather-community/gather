# frozen_string_literal: true

require "rails_helper"

describe Meals::Type do
  it "has valid factory" do
    create(:meal_type)
  end
end
