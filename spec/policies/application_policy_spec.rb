# frozen_string_literal: true

require "rails_helper"

describe ApplicationPolicy do
  include_context "policy permissions"

  describe "permission with named conditions" do
    subject(:policy) { policy_class.new(user, record) }

    let(:record) { double(signed_up?: signed_up, full?: full) }
    let(:signed_up) { false }
    let(:full) { false }
    let(:policy_class) do
      Class.new(ApplicationPolicy) do
        permission :signup? do
          deny_if(:already_signed_up) { record.signed_up? }
          deny_unless(:slots_exceeded) { !record.full? }
        end
      end
    end

    context "with no condition refusing" do
      it "permits, and has no reason to give" do
        expect(policy.signup?).to be(true)
        expect(policy.with_reason.signup?).to be_nil
      end
    end

    context "with one condition refusing" do
      let(:full) { true }

      it "refuses, and names the condition" do
        expect(policy.signup?).to be(false)
        expect(policy.with_reason.signup?).to eq(:slots_exceeded)
      end
    end

    context "with several conditions refusing" do
      let(:signed_up) { true }
      let(:full) { true }

      it "names the first one" do
        expect(policy.with_reason.signup?).to eq(:already_signed_up)
      end
    end

    # A plain predicate has no conditions to read a reason off, and answering nil would read as
    # though it had permitted the action.
    it "raises when asked the reason for a check that doesn't name its conditions" do
      expect { policy.with_reason.show? }.to raise_error(ArgumentError, /not declared/)
    end

    it "raises when asked about a check that doesn't exist" do
      expect { policy.with_reason.nonsense? }.to raise_error(NoMethodError)
    end

    it "doesn't declare the check on other policies" do
      expect { UserPolicy.new(user, user).denial_reason(:signup?) }.to raise_error(ArgumentError)
    end
  end
end
