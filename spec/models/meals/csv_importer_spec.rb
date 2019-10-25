# frozen_string_literal: true

require "rails_helper"

describe Meals::CsvImporter do
  subject(:importer) { described_class.new(file).tap(&:import) }

  context "with empty file" do
    let(:file) { prepare_expectation("empty.csv") }

    it "returns error" do
      expect(importer.errors).to eq(0 => ["File is empty"])
    end
  end

  context "with unrecognized headers including valid headers in other locale" do
    let!(:roles) { create_list(:meal_role, 2) }
    let(:file) { prepare_expectation("meals/import/bad_headers.csv", role_id: roles.map(&:id)) }

    it "returns error listing all bad headers" do
      expect(importer.errors).to eq(1 => ["Invalid column headers: Junk, Heure, Role999999999999"])
    end
  end
end
