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
    let!(:real_role) { create(:meal_role, community: community, title: "Head Cook") }
    let(:outside_role) { create(:meal_role, community: other_community, title: "Vulpt") }
    let(:file) do
      prepare_expectation("meals/import/bad_headers.csv",
        role_id: (roles << outside_role).map(&:id))
    end

    it "returns error listing all bad headers" do
      expect(importer.errors).to eq(
        1 => ["Invalid column headers: Junk, Heure, Role999999999999, Vulpt, Role#{outside_role.id}"]
      )
    end
  end

  context "with bad data" do
    let(:outside_resource) { create(:resource, community: other_community, name: "Plizz") }
    let(:outside_formula) { create(:meal_formula, community: other_community, name: "Blorph") }
    let(:outside_user) { create(:user, community: other_community, first_name: "X", last_name: "Q") }
    let(:outside_community) do
      ActsAsTenant.with_tenant(create(:cluster)) { create(:community, name: "Sooville") }
    end
    let(:file) do
      prepare_expectation("meals/import/bad_data.csv", role_id: roles.map(&:id),
                                                       resource_id: [outside_resource.id],
                                                       formula_id: [outside_formula.id],
                                                       user_id: [outside_user.id],
                                                       community_id: [outside_community.id])
    end

    it "returns all errors" do
      expect(importer.errors).to eq(
        2 => [
          "'notadate' is not a valid date/time",
          "Could not find a resource with ID #{outside_resource.id}",
          "Could not find a resource with ID 18249187214",
          "Could not find a meal formula with ID #{outside_formula.id}",
          "Could not find a community with ID #{outside_community.id}",
          "Could not find a community with ID 6822411",
          "Could not find a user with ID #{outside_user.id}",
          "Could not find a user with ID 818181731"
        ],
        3 => [
          "'2019-01-32 12:43' is not a valid date/time",
          "Could not find a resource named 'Plizz'",
          "Could not find a resource named 'Pants Room'",
          "Could not find a meal formula named 'Blorph'",
          "Could not find a community named 'Saucy Community'",
          "Could not find a community named 'Sooville'",
          "Could not find a user named 'James Smith, Jr.'",
          "Could not find a user named 'X Q'"
        ],
        5 => [
          "Date/time is required",
          "Resource(s) are required"
        ]
      )
    end
  end
end
