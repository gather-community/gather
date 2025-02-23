# frozen_string_literal: true

require "rails_helper"

describe Meals::Import do
  let!(:community) { Defaults.community }
  let!(:other_community) { create(:community, name: "Barville", abbrv: "bv") }
  let(:roles) { create_list(:meal_role, 2) }
  let(:user) { create(:meals_coordinator) }
  let(:import_object) { create(:meal_import, community: community, user: user, csv: csv) }

  context "before run" do
    let(:import) { import_object }
    let(:csv) { prepare_fixture("empty.csv") }

    it "sets status" do
      expect(import.status).to eq("queued")
      import.import
      expect(import.status).to eq("finished")
    end
  end

  context "after run" do
    let(:import) { import_object.tap { |i| i.import && i.reload } }

    context "with empty file" do
      let(:csv) { prepare_fixture("empty.csv") }

      it "returns error and sets status" do
        expect(import.errors_by_row).to eq("0" => ["File is empty"])
      end
    end

    context "with headers but no data" do
      let(:csv) { prepare_fixture("meals/import/no_data.csv") }

      it "returns error" do
        expect(import.errors_by_row).to eq("0" => ["File is empty"])
      end
    end

    context "with unrecognized headers including valid headers in other locale" do
      let!(:real_role) { create(:meal_role, title: "Head Cook") }
      let!(:inactive_role) { create(:meal_role, :inactive, title: "Inacto") }
      let!(:outside_role) { create(:meal_role, community: other_community, title: "Vulpt") }
      let(:csv) do
        prepare_fixture("meals/import/bad_headers.csv",
                        role_id: (roles << outside_role).map(&:id))
      end

      it "returns error listing all bad headers, case insensitive" do
        expect(import.errors_by_row).to eq(
          "1" => ["Invalid column headers: Junk, Heure, Role999999999999, " \
                  "Vulpt, Role#{outside_role.id}, Inacto"]
        )
      end
    end

    context "with missing required headers" do
      let!(:formula) { create(:meal_formula, name: "Foo") }
      let(:csv) { prepare_fixture("meals/import/missing_required_headers.csv") }

      it "returns error" do
        expect(import.errors_by_row).to eq(
          "1" => ["Missing columns: Date/Time, Locations"]
        )
      end
    end

    context "with bad data" do
      let!(:inactive_calendar) { create(:calendar, :inactive, name: "Inacto") }
      let!(:inactive_formula) { create(:meal_formula, :inactive, name: "Inacto") }
      let!(:inactive_user) { create(:user, :inactive, first_name: "I", last_name: "J") }
      let!(:outside_calendar) do
        ActsAsTenant.with_tenant(create(:cluster)) do
          create(:calendar, community: create(:community), name: "Plizz")
        end
      end
      let!(:outside_formula) { create(:meal_formula, community: other_community, name: "Blorph") }
      let!(:outside_user) { create(:user, community: other_community, first_name: "X", last_name: "Q") }
      let!(:outside_community) do
        ActsAsTenant.with_tenant(create(:cluster)) { create(:community, name: "Sooville") }
      end
      let(:csv) do
        prepare_fixture("meals/import/bad_data.csv", role_id: roles.map(&:id),
                                                     calendar_id: [outside_calendar.id],
                                                     formula_id: [outside_formula.id],
                                                     user_id: [outside_user.id],
                                                     community_id: [outside_community.id])
      end

      it "returns all errors" do
        expect(import.errors_by_row).to eq(
          "2" => [
            "'notadate' is not a valid date/time",
            "Could not find a calendar with ID #{outside_calendar.id}",
            "Could not find a calendar with ID 18249187214",
            "Could not find a meal formula with ID #{outside_formula.id}",
            "Could not find a community with ID #{outside_community.id}",
            "Could not find a community with ID 6822411",
            "Could not find a user with ID #{outside_user.id}",
            "Could not find a user with ID 818181731"
          ],
          "3" => [
            "'2019-01-32 12:43' is not a valid date/time",
            "Could not find a calendar named 'Plizz'",
            "Could not find a calendar named 'Pants Room'",
            "Could not find a meal formula named 'Blorph'",
            "Could not find a community named 'Saucy Community'",
            "Could not find a community named 'Sooville'",
            "Could not find a user named 'James Smith, Jr.'",
            "Could not find a user named 'X Q'"
          ],
          "5" => [
            "Date/time is required",
            "Calendar(s) are required"
          ],
          "6" => [
            "Date/time is required",
            "Could not find a calendar named 'Inacto'",
            "Could not find a meal formula named 'Inacto'",
            "Could not find a user named 'I J'"
          ]
        )
      end
    end

    context "with data causing validation errors" do
      let!(:formula) { create(:meal_formula, is_default: true) }
      let!(:calendar) { create(:calendar, name: "Kitchen") }
      let(:csv) do
        prepare_fixture("meals/import/data_with_validation_error.csv", calendar_id: [calendar.id])
      end

      it "returns errors on valid rows and saves no meals" do
        expect(import.errors_by_row).to eq(
          "3" => ["The following error(s) occurred in making a Kitchen event for this meal: " \
                  "This event overlaps an existing one."],
          "4" => ["Could not find a meal formula with ID 1234"]
        )
        expect(Meals::Meal.count).to be_zero
      end
    end

    context "with successful data" do
      let!(:default_formula) { create(:meal_formula, :with_two_roles, is_default: true) }
      let!(:asst_cook_role) { default_formula.roles[1] }
      let!(:other_formula) { create(:meal_formula, name: "Qux") }
      let!(:calendars) { [create(:calendar, name: "Large"), create(:calendar, name: "Foo")] }
      let!(:users) do
        [create(:user), create(:user), create(:user, first_name: "John", last_name: "Fish")]
      end
      let!(:communities) { [community, other_community, create(:community)] }
      let(:csv) do
        prepare_fixture("meals/import/successful_data.csv",
                        calendar_id: calendars.map(&:id),
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
        expect(import).to be_successful
        expect(meals.size).to eq(2)

        expect(meals[0].served_at).to eq(Time.zone.parse("2019-01-31 12:00"))
        expect(meals[0].calendars).to match_array(calendars)
        expect(meals[0].formula).to eq(default_formula)
        expect(meals[0].communities).to match_array(communities)
        expect(meals[0].community).to eq(community)
        expect(meals[0].head_cook).to eq(users[0])
        expect(meals[0].assignments_by_role[asst_cook_role].map(&:user))
          .to contain_exactly(users[1], users[2])
        expect(meals[0].creator).to eq(user)
        expect(meals[0].capacity).to eq(42)

        expect(meals[1].served_at).to eq(Time.zone.parse("2019-02-01 13:00"))
        expect(meals[1].calendars).to eq([calendars[0]])
        expect(meals[1].formula).to eq(other_formula)
        expect(meals[1].communities).to match_array(communities[0..1])
        expect(meals[1].community).to eq(community)
        expect(meals[1].head_cook).to be_nil
        expect(meals[1].assignments_by_role).to be_empty
        expect(meals[1].creator).to eq(user)
        expect(meals[1].capacity).to eq(42)
      end
    end

    context "with encoding issue" do
      let(:csv) { prepare_fixture("meals/import/with_bom.csv") }
      let!(:calendar) { create(:calendar, name: "Kitchen") }
      let!(:formula) { create(:meal_formula, is_default: true) }

      it "still works" do
        expect(import).to be_successful
      end
    end

    context "with action column" do
      let!(:formula) { create(:meal_formula, is_default: true) }
      let!(:formula2) { create(:meal_formula, name: "Pizza") }
      let!(:calendars) { [create(:calendar, name: "Foo"), create(:calendar, name: "Bar")] }

      context "when can't find existing meal for update or destroy" do
        let(:csv) { prepare_fixture("meals/import/missing_existing_meals.csv") }

        it "fails and doesn't save valid meal" do
          expect(import.errors_by_row).to eq(
            "2" => ["Could not find a calendar named 'Blah'"],
            "3" => ["Could not find meal served at Thu Jan 31 2019 12:00pm at locations: Foo"],
            "4" => ["Could not find meal served at Fri Feb 01 2019 1:00pm at locations: Foo"],
            "6" => ["Invalid action: baloney"]
          )
          expect(Meals::Meal.count).to be_zero
        end
      end

      # Create and update are not interesting
      context "with destroy permission issues" do
        let!(:meal) { create(:meal, :finalized, served_at: "2019-01-31 12:00", calendars: [calendars[0]]) }
        let(:csv) { prepare_fixture("meals/import/destroy_permission_errors.csv") }

        it "fails with correct errors" do
          expect(import.errors_by_row).to eq("2" => ["Action not permitted (destroy)"])
        end
      end

      context "with valid data" do
        let!(:user1) { create(:user, first_name: "Pol", last_name: "Pum") }
        let!(:user2) { create(:user, first_name: "Bil", last_name: "Bip") }
        let!(:meal1) { create(:meal, served_at: "2019-01-31 12:00", calendars: calendars) }
        let!(:meal2) do
          create(:meal, served_at: "2019-02-01 12:00", calendars: calendars,
                        formula: formula, head_cook: user1, communities: [community])
        end
        let!(:meal3) do
          create(:meal, :finalized, served_at: "2019-02-02 12:00", calendars: calendars,
                                    formula: formula, head_cook: user1, communities: [community])
        end
        let(:csv) { prepare_fixture("meals/import/successful_data_with_actions.csv") }

        it "succeeds, ignoring case for action, ignoring calendar order, ignoring unpermitted fields" do
          expect(import).to be_successful
          expect { meal1.reload }.to raise_error(ActiveRecord::RecordNotFound)

          # meal2 formula should have changed b/c it's not finalized
          meal2.reload
          expect(meal2.calendars).to match_array(calendars)
          expect(meal2.formula).to eq(formula2)
          expect(meal2.head_cook).to eq(user2)
          expect(meal2.communities).to contain_exactly(community, other_community)

          # meal3 formula should not have changed b/c it's finalized
          meal3.reload
          expect(meal3.calendars).to match_array(calendars)
          expect(meal3.formula).to eq(formula)
          expect(meal3.head_cook).to eq(user2)
          expect(meal3.communities).to contain_exactly(community, other_community)
        end
      end

      context "with optional ID column" do
        let!(:meal1) { create(:meal, served_at: "2019-01-31 12:00", calendars: [calendars[0]]) }

        context "with correct data" do
          let(:csv) { prepare_fixture("meals/import/actions_with_id_column.csv", meal_id: [meal1.id]) }

          it "succeeds with update and ignores for create" do
            expect(import).to be_successful
            meal1.reload
            expect(meal1.served_at).to eq(Time.zone.parse("2019-02-01 12:00"))
            expect(meal1.calendars).to contain_exactly(calendars[1])
            expect(Meals::Meal.count).to eq(2)
          end
        end

        context "with invalid ID for update" do
          let(:csv) { prepare_fixture("meals/import/actions_with_invalid_id.csv") }

          it "errors" do
            expect(import.errors_by_row).to eq("2" => ["Could not find meal with ID '1827648312341'"])
          end
        end
      end
    end
  end
end
