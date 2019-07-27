# frozen_string_literal: true

require "rails_helper"

describe Meals::SignupPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:meal) { create(:meal, communities: [community, communityC]) }
    let(:signup) { create(:meal_signup, :with_nums, meal: meal) }

    shared_examples_for "must be invited, open, and in future" do
      context "in future and open" do
        before do
          allow(meal).to receive(:in_past?).and_return(false)
          allow(meal).to receive(:open?).and_return(true)
        end

        it "permits invitees" do
          expect(subject).to permit(user, signup)
          expect(subject).to permit(user_cmtyC, signup)
        end

        it "forbids non-invitees, even admins" do
          expect(subject).not_to permit(user_cmtyB, signup)
          expect(subject).not_to permit(admin_cmtyB, signup)
        end
      end

      context "in future and closed" do
        before do
          allow(meal).to receive(:in_past?).and_return(false)
          allow(meal).to receive(:open?).and_return(false)
        end

        it "forbids invitees" do
          expect(subject).not_to permit(user, signup)
        end
      end

      context "in past and open" do
        before do
          allow(meal).to receive(:in_past?).and_return(true)
          allow(meal).to receive(:open?).and_return(true)
        end

        it "forbids invitees" do
          expect(subject).not_to permit(user, signup)
        end
      end
    end

    permissions :create? do
      it_behaves_like "must be invited, open, and in future"

      it "forbids inactive users" do
        expect(subject).not_to permit(inactive_user, signup)
      end

      context "when in future and open but full" do
        before do
          allow(meal).to receive(:in_past?).and_return(false)
          allow(meal).to receive(:open?).and_return(true)
          allow(meal).to receive(:full?).and_return(true)
        end

        it "forbids invitees" do
          expect(subject).not_to permit(user, signup)
        end
      end
    end

    permissions :update? do
      it_behaves_like "must be invited, open, and in future"

      it "permits inactive users" do
        expect(subject).to permit(inactive_user, signup)
      end

      context "when in future and open but full" do
        before do
          allow(meal).to receive(:in_past?).and_return(false)
          allow(meal).to receive(:open?).and_return(true)
          allow(meal).to receive(:full?).and_return(true)
        end

        it "permits invitees" do
          expect(subject).to permit(user, signup)
        end
      end
    end
  end

  describe "permitted_attributes" do
    let(:user) { User.new }
    subject { described_class.new(user, Meals::Signup.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:id, :household_id, :comments, :meal_id,
        lines_attributes: %i[id type_id count _destroy])
    end
  end
end
