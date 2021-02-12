# frozen_string_literal: true

class AddCountryCodeToPeopleEmergencyContacts < ActiveRecord::Migration[6.0]
  def change
    add_column :people_emergency_contacts, :country_code, :string, limit: 2
    execute("UPDATE people_emergency_contacts SET country_code = 'US'")
    change_column_null :people_emergency_contacts, :country_code, false
  end
end
