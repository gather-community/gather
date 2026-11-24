# frozen_string_literal: true

require "rails_helper"

# The signup form itself is covered by spec/system/meals/signups_form_spec.rb. This covers a case a
# browser spec can't easily set up: the meal being deleted while the form is open.
describe "meal signups" do
  let(:actor) { create(:user) }
  let(:meal) { create(:meal) }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  it "redirects to the meals page with a message if the meal no longer exists" do
    parts = {"0" => {type_id: meal.types[0].id, count: 1}}
    params = {meals_signup: {meal_id: meal.id, parts_attributes: parts}}
    meal.destroy
    post("/meals/signups", params: params, xhr: true)
    expect(response).to be_successful
    expect(response.parsed_body).to eq("redirect" => "/meals")
    expect(flash[:error]).to eq("Your signup could not be recorded because the meal no longer exists.")
    expect(Meals::Signup.count).to eq(0)
  end
end
