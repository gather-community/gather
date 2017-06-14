module Faker
  class PhoneNumber
    def self.simple
      "+1" <<
        (2..8).to_a.sample.to_s <<
        [0,1].sample.to_s <<
        (2..8).to_a.sample.to_s <<
        7.times.map { (0..9).to_a.sample }.join
    end
  end

  class Name
    def self.unisex_name
      I18n.t("random_data.unisex_names").sample
    end
  end

  class Relationship
    def self.relationship
      I18n.t("random_data.relationships").sample
    end
  end

  class Car
    MAKES = %w(Ford GMC Chevy Chrysler Buick Honda Toyota Opel Suzuki Subaru Hyundai)
    MODELS = %w(Speeder Go Vroomy Perambulator Carcar Haulor Laser Zoomex Horsey)

    def self.make
      MAKES.sample
    end

    def self.model
      MODELS.sample
    end
  end
end
