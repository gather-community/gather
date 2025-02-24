# frozen_string_literal: true

require "rails_helper"

describe "user request" do
  let(:user) { create(:user) }
  let(:new_household) { create(:household) }
  let(:outside_household) { create(:household, community: create(:community)) }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  describe "create" do
    let(:actor) { create(:admin) }
    let(:basic_params) do
      {
        household_by_id: "true",
        first_name: "Foo",
        last_name: "Bar",
        email: "foo@bar.com",
        mobile_phone: "2345678901",
        household_id: new_household.id
      }
    end

    context "creating normally" do
      it "should succeed" do
        post users_path, params: {user: basic_params}
        expect_successful_create_or_update
      end
    end

    context "creating with outside household" do
      it "should error" do
        expect do
          post(users_path, params: {user: basic_params.merge(household_id: outside_household.id)})
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe "update" do
    let(:actor) { create(:admin) }

    context "trying to change to authorized household" do
      it "should succeed" do
        patch user_path(user), params: {user: {household_by_id: "true", household_id: new_household.id}}
        expect_successful_create_or_update
      end
    end

    context "when not admin but operating on self" do
      let(:actor) { user }

      context "changing non-restricted attrib" do
        it "should succeed" do
          patch user_path(user), params: {user: {
            household_by_id: "true",
            household_id: user.household_id,
            first_name: "Jorpo"
          }}
          expect_successful_create_or_update

          expect(user.reload.first_name).to eq("Jorpo")
        end
      end

      context "trying to change household" do
        it "should error" do
          expect do
            patch(user_path(user),
                  params: {user: {household_by_id: "true", household_id: new_household.id}})
          end.to raise_error(Pundit::NotAuthorizedError)
        end
      end
    end

    context "trying to change to unauthorized household" do
      it "should error" do
        expect do
          patch(user_path(user),
                params: {user: {household_by_id: "true", household_id: outside_household.id}})
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "trying to change household via nested attributes" do
      it "should not change household" do
        patch user_path(user), params: {user: {
          household_by_id: "false",
          household_attributes: {
            id: new_household.id
          }
        }}
        expect(user.reload.household_id).not_to eq(new_household.id)
      end
    end
  end

  def expect_successful_create_or_update
    expect(response).to be_redirect
    expect(flash[:success]).to be_present
  end
end
