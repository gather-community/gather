require 'rails_helper'

describe Meals::MessagePolicy do
  describe "permissions" do
    include_context "policy objs"

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
end
