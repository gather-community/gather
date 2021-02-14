# frozen_string_literal: true

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
