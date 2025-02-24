# frozen_string_literal: true

module People
  # This is really a decorator class. Not persisted.
  class PhoneNumber
    attr_reader :model, :kind

    def initialize(model, kind)
      @model = model
      @kind = kind
    end

    delegate :blank?, to: :raw
    delegate :country_code, to: :model

    def raw
      model.read_attribute(attrib)
    end

    def formatted(kind_abbrv: false, show_country: false, format: :national)
      result = errors.any? ? raw : raw&.phony_formatted(format: format)
      return nil if result.nil?

      if kind_abbrv
        kind_abbrv = I18n.t("phone_types.abbreviations.#{kind}")
        result = "#{result} #{kind_abbrv}"
      end
      if show_country
        raise ArgumentError("Phone number country requested but nil") if country_code.nil?

        country = ISO3166::Country[country_code]
        country_name = country.translations[I18n.locale.to_s] || country.name
        result = "#{result} (#{country_name})"
      end
      result
    end

    private

    def errors
      model.errors[attrib]
    end

    def attrib
      :"#{kind}_phone"
    end
  end
end
