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

  def phone(kind)
    People::PhoneNumber.new(self, kind)
  end

  # Returns an array of all raw phone numbers
  def phones
    phone_types.map { |k| phone(k) }.reject(&:blank?)
  end

  def phone_list
    phones.map { |p| p.formatted(kind_abbrv: true) }.join(", ")
  end

  def no_phones?
    phone_types.all? { |t| send("#{t}_phone").nil? }
  end
end
