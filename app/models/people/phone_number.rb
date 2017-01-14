module People
  class PhoneNumber
    attr_reader :model, :kind

    def initialize(model, kind)
      @model = model
      @kind = kind
    end

    def blank?
      raw.blank?
    end

    def raw
      model.read_attribute(attrib)
    end

    def formatted(options = {})
      result = if errors.any?
        raw.try(:sub, /\A\+/, "")
      else
        raw.try(:phony_formatted, format: :national)
      end

      if options[:kind_abbrv] && result
        kind_abbrv = I18n.t("phone_types.abbreviations.#{kind}")
        result = "#{formatted} #{kind_abbrv}"
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
