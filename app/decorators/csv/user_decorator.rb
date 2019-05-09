# frozen_string_literal: true

module Csv
  # Decorates User for CSV export
  class UserDecorator < ::UserDecorator
    delegate_all

    delegate :unit_num, :unit_suffix, :garage_nums, :keyholders, to: :household

    def birthdate
      object.birthday.str(formats: %i[csv_month_day csv_full])
    end

    def guardian_names
      return nil if guardians.none?
      guardians.active.decorate.map(&:full_name).sort.join(", ")
    end

    def joined_on
      l(object.joined_on)
    end

    def child
      bool(object.child?)
    end

    def vehicles
      adult? && household.vehicles.any? ? household.vehicles.map(&:to_s).sort.join("; ") : nil
    end

    def emergency_contacts
      return nil if household.emergency_contacts.none?
      chunks = household.emergency_contacts.map do |contact|
        ["#{contact.name} (#{contact.relationship})", contact.location, contact.phone(:main).formatted,
         contact.phone(:alt).formatted, contact.email].compact.join(", ")
      end
      chunks.sort.join("; ")
    end

    def pets
      return nil if household.pets.none?
      chunks = household.pets.map do |pet|
        "#{pet.name} (#{pet.color} #{pet.species})"
      end
      chunks.sort.join("; ")
    end

    private

    def l(date_or_time)
      return nil if date_or_time.nil?
      I18n.l(date_or_time, format: :csv_full)
    end

    def bool(val)
      I18n.t("common.#{val ? 'true' : 'false'}")
    end
  end
end
