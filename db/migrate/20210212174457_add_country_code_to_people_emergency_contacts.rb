# frozen_string_literal: true

class AddCountryCodeToPeopleEmergencyContacts < ActiveRecord::Migration[6.0]
  def change
    add_column :people_emergency_contacts, :country_code, :string, default: "us", null: false, limit: 2
  end
end
