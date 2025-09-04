# frozen_string_literal: true

# == Schema Information
#
# Table name: people_emergency_contacts
#
#  id           :integer          not null, primary key
#  alt_phone    :string
#  cluster_id   :integer          not null
#  country_code :string(2)        not null
#  created_at   :datetime         not null
#  email        :string(255)
#  household_id :integer
#  location     :string           not null
#  main_phone   :string           not null
#  name         :string           not null
#  relationship :string           not null
#  updated_at   :datetime         not null
#
require "rails_helper"

describe People::EmergencyContact do
  # This tests that country_code is defined on emergency_contact and picked up by the Phoneable concern.
  # See phoneable_spec.rb for more phone normalization and validation specs.
  context "phone normalization with non-US country code" do
    let(:contact) { create(:emergency_contact, main_phone: phone, alt_phone: nil, country_code: "NZ") }

    context "should properly normalize phone number" do
      let(:phone) { "21345678" }
      it { expect(contact.main_phone).to eq("+6421345678") }
    end
  end
end
