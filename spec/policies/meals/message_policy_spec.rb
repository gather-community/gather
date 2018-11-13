# frozen_string_literal: true

require "rails_helper"

describe Meals::MessagePolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:meal) { create(:meal, cleaners: [user]) }

    before do
      save_policy_objects!(community, user)
    end

    context "with meal set" do
      let(:message) { Meals::Message.new(meal: meal, sender: user) }

      permissions :index?, :show?, :edit?, :update?, :destroy? do
        it "denies access" do
          expect(subject).not_to permit(user, message)
        end
      end

      # More detailed tests of these permissions in meal policy spec.
      # This spec mostly tests connection of this policy to meal policy.
      permissions :new?, :create? do
        it "permits team members" do
          expect(subject).to permit(user, message)
        end

        it "denies others" do
          expect(subject).not_to permit(other_user, message)
        end
      end
    end

    context "with no meal set" do
      let(:message) { Meals::Message.new(sender: user) }

      it "raises error" do
        expect { Meals::MessagePolicy.new(user, message).new? }.to raise_error(ArgumentError)
      end
    end
  end

  describe "permitted attributes" do
    subject { Meals::MessagePolicy.new(User.new, Meals::Message.new).permitted_attributes }

    it "should allow basic attribs" do
      expect(subject).to contain_exactly(:kind, :body, :recipient_type)
    end
  end
end
