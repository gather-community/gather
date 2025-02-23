# frozen_string_literal: true

# Handles normalizing and displaying phone numbers
module Phoneable
  extend ActiveSupport::Concern

  included do |_base|
    def self.handle_phone_types(*phone_types)
      class_variable_set("@@phone_types", phone_types)

      phone_types.each do |p|
        # country_code should be present on model and is auto-detected by Phony
        validates_plausible_phone("#{p}_phone")
        phony_normalize("#{p}_phone", normalize_when_valid: true)
      end
    end
  end

  def phone_types
    self.class.class_variable_get("@@phone_types")
  end

  def phone(kind = nil)
    kind ||= phone_types[0]
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
