require "rails_helper"
include ActionView::Helpers

describe Meals::Importer, type: :model do
  describe "import" do
    let!(:current_community) { create(:community) }

    before do
      Meal.new_with_defaults(current_community)
      pp current_community, 'spec'
    end

    it "creates users with varying amounts of info" do
      mi = create_meal_batch("varying_info.csv")
      expect(mi).to be_succeeded

      assert_meal_attribs(mi.meals[0],
        capacity: 30, created_at: "2018-01-31", location: "Touchstone housing; Green house",
        formula: "Formula name", head_cook: "Ijeoma Arisah", extra_roles: "")
      assert_meal_attribs(mi.meals[1],
        capacity: 40, created_at: "2018-02-05", location: "Grey housing; White house",
        formula: "Another name", head_cook: "Cjay Ndubisi", extra_roles: "")
      assert_meal_attribs(mi.meals[2],
        capacity: 50, created_at: "2018-02-10", location: "Mary housing; Orange house",
        formula: "Formula again", head_cook: "Scrabble Game", extra_roles: "")
      assert_meal_attribs(mi.meals[3],
        capacity: 20, created_at: "2018-02-18", location: "Citdel housing; Pink house",
        formula: "Name name", head_cook: "AC Bad", extra_roles: "")
      assert_meal_attribs(mi.meals[4],
        capacity: 30, created_at: "2018-02-28", location: "Association housing; Wine house",
        formula: "Formula namely", head_cook: "Ijebu Garri", extra_roles: "")

      expect(Meal.count).to eq 5
    end

    it "creates meals from csv" do
      mi = create_meal_batch("user_batch_3.csv")
      expect(mi).to be_succeeded

      expect(User.count).to eq 3
      expect(Assignment.count).to eq 3
    end

    it "ignores blank lines" do
      mi = create_meal_batch("blank_lines.xlsx")
      expect(mi).to be_succeeded
      expect(2).to eq(mi.meals.size)
    end

    it "succeeds when headers have trailing invisible blanks" do
      mi = create_meal_batch("abnormal_headers.xlsx")
      expect(mi).to be_succeeded
    end

    it "works with one row" do
      mi = create_meal_batch("one_row.xlsx")
      expect(mi).to be_succeeded
      expect(User.count).to eq 1
    end

    it "gracefully handles missing header row with a number in it" do
      mi = create_meal_batch("missing_headers.xlsx")
      expect(mi).not_to be_succeeded
      expect(mi.errors.messages.values).to eq([["The uploaded spreadsheet has invalid headers."]])
    end

    context "when checking validation errors on spreadsheet" do
      it "handles validation errors gracefully" do
        # create batch that should raise too short phone number error
        mi = create_meal_batch("validation_errors.xlsx")
        expect(mi).not_to be_succeeded

        expect(mi.meals[0].errors.full_messages.join).to match(/at least \d+ digits/)
      end

      it "checks for phone uniqueness on both numbers, ignoring deleted data" do
        create(:user, :deleted, phone: "+983755482") # Decoy

        mi = create_meal_batch("phone_problems.xlsx")
        expect(mi).not_to be_succeeded

        error_messages = mi.errors.messages.values
        expect(error_messages.length).to eq 4
        expect(error_messages[0]).to eq ["Row 2: Main Phone: Please enter a unique value."]
        expect(error_messages[1]).to eq ["Row 4: Main Phone: Please enter a unique value."]
        expect(error_messages[2]).to eq ["Row 5: Alternate Phone: Please enter a unique value."]
        expect(error_messages[3]).to eq ["Row 5: Main Phone: Please enter a unique value."]
      end

      it "does not check for email uniqueness" do
        mi = create_meal_batch("duplicate_emails.xlsx")
        expect(mi).to be_succeeded
      end
    end

    context "when checking uniqueness on db" do
      before do
        # a@bc.com also exists in fixure but we don't care about email uniqueness
        create(:user, login: "a.bob", name: "A Bob", phone: "+2279182137", phone2: nil, email: "a@bc.com")
        create(:user, phone: "+9837494434", phone2: "+983755482")
      end

      it "checks for duplicate usernames and phones" do
        mi = create_meal_batch("varying_info.xlsx")
        expect(mi).not_to be_succeeded
        error_messages = mi.errors.messages.values

        expect(error_messages.length).to eq 4
        expect(error_messages[0]).to eq ["Row 2: Username: Please enter a unique value."]
        expect(error_messages[1]).to eq ["Row 2: Main Phone: Please enter a unique value."]
        expect(error_messages[2]).to eq ["Row 6: Alternate Phone: Please enter a unique value."]
        expect(error_messages[3]).to eq ["Row 6: Main Phone: Please enter a unique value."]
      end
    end

    private

    def assert_meal_attribs(meal, attribs)
      # make sure meal is valid (no need to call valid? since it all validations were set during import)
      expect(meal.errors.empty?).to be_truthy

      # check attribs
      expect(meal).to have_attributes(attribs)
    end

    def fixture(name)
      File.open File.expand_path("../../../fixtures/files/meals/#{name}", __FILE__)
    end

    def create_meal_batch(file)
      mi = Meals::Importer.new
      mi.import(fixture(file), current_community)
      mi
    end
  end
end
