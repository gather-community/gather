# Expects PHONE_TYPES to be defined on the including model
module Phoneable
  extend ActiveSupport::Concern

  included do |base|
    def self.handle_phone_types(*phone_types)
      class_variable_set("@@phone_types", phone_types)

      phone_types.each do |p|
        phony_normalize "#{p}_phone", default_country_code: 'US'
        validates_plausible_phone "#{p}_phone", normalized_country_code: 'US', country_number: '1'
      end
    end
  end

  def phone_types
    self.class.class_variable_get("@@phone_types")
  end

  # Returns formatted phone number, except if phone number has errors, returns raw value w/o +.
  def format_phone(type)
    attrib = :"#{type}_phone"
    if errors[attrib].any?
      read_attribute(attrib).try(:sub, /\A\+/, "")
    else
      read_attribute(attrib).try(:phony_formatted, format: :national)
    end
  end

  # Returns a string with all non-nil phone numbers
  def phones
    phone_types.map do |type|
      num = format_phone(type)
      if num
        type_abbrv = I18n.t("phone_types.abbreviations.#{type}")
        "#{num} #{type_abbrv}"
      else
        nil
      end
    end.compact
  end

  def no_phones?
    phone_types.all? { |t| send("#{t}_phone").nil? }
  end
end
