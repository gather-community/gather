require 'rails_helper'

describe SignupPolicy do
  describe "permissions" do
    include_context "policy objs"

    let(:meal) { build(:meal, community: community, communities: [community, communityC]) }
    let(:signup) { build(:signup, meal: meal) }

    shared_examples_for "invited" do
      it "permits invitees" do
        expect(subject).to permit(user, signup)
        expect(subject).to permit(user_in_cmtyC, signup)
      end

      it "forbids non-invitees, even admins" do
        expect(subject).not_to permit(user_in_cmtyB, meal)
        expect(subject).not_to permit(admin_in_cmtyB, meal)
      end
    end

    permissions :create? do
      it_behaves_like "invited"

      it "forbids inactive users" do
        expect(subject).not_to permit(inactive_user, signup)
      end
    end

    permissions :update? do
      it_behaves_like "invited"

      it "permits inactive users" do
        expect(subject).to permit(inactive_user, signup)
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
