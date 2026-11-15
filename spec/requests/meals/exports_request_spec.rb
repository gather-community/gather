# frozen_string_literal: true

require "rails_helper"

# The download itself is covered by spec/system/meals/export_spec.rb. These cover the pieces a
# browser spec can't reach: authorization and bad params.
describe "meal csv exports" do
  let!(:formula) { create(:meal_formula, is_default: true) }
  let!(:meal) { create(:meal, :with_menu, formula: formula, served_at: "2019-05-15 18:00") }
  let!(:signup) { create(:meal_signup, meal: meal, diner_counts: [2]) }
  let(:dates) { "20190101-20191231" }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  context "as meals coordinator" do
    let(:actor) { create(:meals_coordinator) }

    it "exports meals" do
      get("/meals.csv?dates=#{dates}")
      expect(response).to be_successful
      expect(response.header["Content-Disposition"])
        .to match(/#{actor.community.slug}-meals-20190101-20191231\.csv/)
      expect(response.body).to match(%r{\ADate/Time,Locations,Formula})
      expect(response.body).to match(/2019-05-15T18:00:00/)
    end

    it "exports signups" do
      get("/meals/signups.csv?dates=#{dates}")
      expect(response).to be_successful
      expect(response.header["Content-Disposition"])
        .to match(/#{actor.community.slug}-meal-signups-20190101-20191231\.csv/)
      expect(response.body).to match(/\AMeal ID,/)
      expect(response.body).to match(/#{signup.household_name}/)
    end

    it "excludes meals outside the date range" do
      get("/meals.csv?dates=20200101-20201231")
      expect(response.body).not_to match(/2019-05-15/)
    end

    it "rejects a missing dates param" do
      expect { get("/meals.csv") }.to raise_error(ActionController::BadRequest)
    end

    it "rejects an unparseable dates param" do
      expect { get("/meals.csv?dates=abcdefgh-20191231") }.to raise_error(ActionController::BadRequest)
    end
  end

  context "as regular user" do
    let(:actor) { create(:user) }

    it "forbids the meals export" do
      expect { get("/meals.csv?dates=#{dates}") }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "forbids the signups export" do
      expect { get("/meals/signups.csv?dates=#{dates}") }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
