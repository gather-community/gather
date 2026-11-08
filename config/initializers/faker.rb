# frozen_string_literal: true

module Faker
  class PhoneNumber
    MAX_ATTEMPTS = 1000

    # A random number that passes our phone validation in the given country. Returns nil for the few
    # places (mostly uninhabited territories) where no random number does.
    def self.simple(country_code: "US")
      calling_code = ISO3166::Country[country_code]&.country_code
      return nil if calling_code.nil?
      MAX_ATTEMPTS.times do
        number = (calling_code == "1") ? north_american : "+#{calling_code}#{random_national}"
        return number if PhonyRails.plausible_number?(number, country_code: country_code)
      end
      nil
    end

    def self.north_american
      +"+1" <<
        (2..8).to_a.sample.to_s <<
        [0, 1].sample.to_s <<
        (2..8).to_a.sample.to_s <<
        7.times.map { (0..9).to_a.sample }.join
    end

    # National numbers range from 4 digits (some small islands) to 12.
    def self.random_national
      rand(1..9).to_s + rand(3..11).times.map { rand(10) }.join
    end
  end

  class Name
    # The same list in every language. These names suit anyone, and they're plain ASCII, which sample email
    # addresses are built from.
    def self.unisex_name
      I18n.t("random_data.unisex_names", locale: :en).sample
    end
  end

  # The lists below are in sample_data.yml, translated, since sample data is in the community's language.

  class Relationship
    def self.relationship
      I18n.t("sample_data.relationships").sample
    end
  end

  class Pet
    def self.species
      I18n.t("sample_data.pet_species").sample
    end
  end

  class Color
    # Faker's own color names are English in several of Gather's languages.
    def self.common_color_name
      I18n.t("sample_data.colors").sample
    end
  end

  class Car
    MAKES = %w[Ford GMC Chevy Chrysler Buick Honda Toyota Opel Suzuki Subaru Hyundai].freeze
    MODELS = %w[Speeder Go Vroomy Perambulator Carcar Haulor Laser Zoomex Horsey].freeze

    def self.make
      MAKES.sample
    end

    def self.model
      MODELS.sample
    end
  end
end
