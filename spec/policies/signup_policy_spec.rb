require 'rails_helper'

describe SignupPolicy do
  describe "permissions" do
    include_context "policy objs"

    shared_examples_for "invited" do
      it "grants access to invitees" do
        expect(subject).to permit(user, Signup.new(meal: Meal.new(communities: [community])))
      end

      it "denies access to non-invitees" do
        expect(subject).not_to permit(user, Signup.new(meal: Meal.new))
      end
    end

    permissions :create? do
      it_behaves_like "invited"

      it "denies access to inactive users" do
        expect(subject).not_to permit(inactive_user, Signup.new(meal: Meal.new(communities: [community])))
      end
    end

    permissions :update? do
      it_behaves_like "invited"

      it "grants access to inactive users" do
        expect(subject).to permit(inactive_user, Signup.new(meal: Meal.new(communities: [community])))
      end
    end
  end

  describe "permitted_attributes" do
    let(:user) { User.new }
    subject { SignupPolicy.new(user, Signup.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(*(Signup::SIGNUP_TYPES + [:meal_id, :comments]))
    end
  end
end
