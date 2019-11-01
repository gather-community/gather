# frozen_string_literal: true

require "rails_helper"

describe Meals::CsvImporter do
  let!(:community) { Defaults.community }
  let!(:other_community) { create(:community, name: "Barville", abbrv: "BV") }
  let(:roles) { create_list(:meal_role, 2) }
  let(:user) { create(:meals_coordinator) }
  subject(:importer) { described_class.new(file, community: community, user: user).tap(&:import) }

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
    let!(:real_role) { create(:meal_role, title: "Head Cook") }
    let!(:inactive_role) { create(:meal_role, :inactive, title: "Inacto") }
    let!(:outside_role) { create(:meal_role, community: other_community, title: "Vulpt") }
    let(:file) do
      prepare_expectation("meals/import/bad_headers.csv",
        role_id: (roles << outside_role).map(&:id))
    end

    it "returns error listing all bad headers, case insensitive" do
      expect(importer.errors).to eq(
        1 => ["Invalid column headers: Junk, Heure, Role999999999999, Vulpt, Role#{outside_role.id}, Inacto"]
      )
    end
  end

  context "with missing required headers" do
    let!(:formula) { create(:meal_formula, name: "Foo") }
    let(:file) { prepare_expectation("meals/import/missing_required_headers.csv") }

    it "returns error" do
      expect(importer.errors).to eq(
        1 => ["Missing columns: Date/Time, Resources"]
      )
    end
  end

  context "with bad data" do
    let!(:inactive_resource) { create(:resource, :inactive, name: "Inacto") }
    let!(:inactive_formula) { create(:meal_formula, :inactive, name: "Inacto") }
    let!(:inactive_user) { create(:user, :inactive, first_name: "I", last_name: "J") }
    let!(:outside_resource) { create(:resource, community: other_community, name: "Plizz") }
    let!(:outside_formula) { create(:meal_formula, community: other_community, name: "Blorph") }
    let!(:outside_user) { create(:user, community: other_community, first_name: "X", last_name: "Q") }
    let!(:outside_community) do
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
        ],
        6 => [
          "Date/time is required",
          "Could not find a resource named 'Inacto'",
          "Could not find a meal formula named 'Inacto'",
          "Could not find a user named 'I J'"
        ]
      )
    end
  end

  context "with data causing validation errors" do
    let!(:formula) { create(:meal_formula, is_default: true) }
    let(:resource) { create(:resource) }
    let(:file) do
      prepare_expectation("meals/import/data_with_validation_error.csv", resource_id: [resource.id])
    end

    it "returns errors on valid rows and saves no meals" do
      expect(importer.errors).to eq(
        2 => [],
        3 => ["The following error(s) occurred in making a Resource 1 reservation for this meal: "\
          "This reservation overlaps an existing one."],
        4 => ["Could not find a meal formula with ID 1234"]
      )
      expect(Meals::Meal.count).to be_zero
    end
  end

  context "with successful data" do
    let!(:default_formula) { create(:meal_formula, :with_two_roles, is_default: true) }
    let!(:asst_cook_role) { default_formula.roles[1] }
    let!(:other_formula) { create(:meal_formula, name: "Qux") }
    let!(:resources) { [create(:resource), create(:resource, name: "Foo")] }
    let!(:users) do
      [create(:user), create(:user), create(:user, first_name: "John", last_name: "Fish")]
    end
    let!(:communities) { [community, other_community, create(:community)] }
    let(:file) do
      prepare_expectation("meals/import/successful_data.csv",
        resource_id: resources.map(&:id),
        role_id: [asst_cook_role.id],
        user_id: users.map(&:id),
        community_id: communities.map(&:id))
    end
    let(:meals) { Meals::Meal.order(:served_at).to_a }

    before do
      community.settings.meals.default_capacity = 42
      community.save!
    end

    it "creates meals with expected attributes, ignoring case" do
      expect(importer).to be_successful
      expect(meals.size).to eq(2)

      expect(meals[0].served_at).to eq(Time.zone.parse("2019-01-31 12:00"))
      expect(meals[0].resources).to match_array(resources)
      expect(meals[0].formula).to eq(default_formula)
      expect(meals[0].communities).to match_array(communities)
      expect(meals[0].community).to eq(community)
      expect(meals[0].head_cook).to eq(users[0])
      expect(meals[0].assignments_by_role[asst_cook_role].map(&:user)).to contain_exactly(users[1], users[2])
      expect(meals[0].creator).to eq(user)
      expect(meals[0].capacity).to eq(42)

      expect(meals[1].served_at).to eq(Time.zone.parse("2019-02-01 13:00"))
      expect(meals[1].resources).to eq([resources[0]])
      expect(meals[1].formula).to eq(other_formula)
      expect(meals[1].communities).to match_array(communities[0..1])
      expect(meals[1].community).to eq(community)
      expect(meals[1].head_cook).to be_nil
      expect(meals[1].assignments_by_role).to be_empty
      expect(meals[1].creator).to eq(user)
      expect(meals[1].capacity).to eq(42)
    end
  end
end
