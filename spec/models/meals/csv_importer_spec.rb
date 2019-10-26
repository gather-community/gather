# frozen_string_literal: true

require "rails_helper"

describe Meals::CsvImporter do
  let(:community) { create(:community) }
  let(:other_community) { create(:community) }
  let(:roles) { create_list(:meal_role, 2, community: community) }
  subject(:importer) { described_class.new(file, community: community).tap(&:import) }

  context "with empty file" do
    let(:file) { prepare_expectation("empty.csv") }

    it "returns error" do
      expect(importer.errors).to eq(0 => ["File is empty"])
    end
  end

  context "with headers but no data" do
    let(:file) { prepare_expectation("meals/import/no_data.csv") }

    it "returns error" do
      expect(importer.errors).to eq(0 => ["File is empty"])
    end
  end

  context "with unrecognized headers including valid headers in other locale" do
    let(:outside_role) { create(:meal_role, community: other_community, title: "Vulpt") }
    let(:file) do
      prepare_expectation("meals/import/bad_headers.csv", role_id: (roles << outside_role).map(&:id))
    end

    it "returns error listing all bad headers" do
      expect(importer.errors).to eq(
        1 => ["Invalid column headers: Junk, Heure, Role999999999999, Vulpt, Role#{outside_role.id}"]
      )
    end
  end
end
