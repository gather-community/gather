# frozen_string_literal: true

require "rails_helper"

describe People::SignInInvitationsPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { user }

    context "with adult" do
      permissions :new?, :create? do
        it_behaves_like "permits admins but not regular users"
      end
    end

    context "with child" do
      let(:user) { create(:user, :child) }

      permissions :new?, :create? do
        it_behaves_like "forbids all"
      end
    end

    permissions :index?, :show?, :edit?, :update?, :destroy? do
      it_behaves_like "forbids all"
    end
  end
end
