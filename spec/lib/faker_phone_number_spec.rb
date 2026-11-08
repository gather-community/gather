# frozen_string_literal: true

require "rails_helper"

# Tests our addition in config/initializers/faker.rb, used for sample data.
describe Faker::PhoneNumber do
  describe ".simple" do
    it "returns numbers that are valid in the given country" do
      %w[US CA GB DE FR AU NZ SE].each do |country|
        20.times do
          number = described_class.simple(country_code: country)
          expect(PhonyRails.plausible_number?(number, country_code: country))
            .to be(true), "#{number} isn't valid in #{country}"
        end
      end
    end

    it "defaults to the US" do
      expect(described_class.simple).to start_with("+1")
    end

    it "returns nil for a place with no phone numbers" do
      # Bouvet Island is uninhabited.
      expect(described_class.simple(country_code: "BV")).to be_nil
    end
  end
end
