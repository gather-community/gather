# frozen_string_literal: true

require "rails_helper"

describe People::SignInInvitationsPolicy do
  describe "permissions" do
    include_context "policy permissions"

    # The record is the community itself since that's all we need to know to determine permissions.
    let(:record) { community }

    permissions :new?, :create? do
      it_behaves_like "permits admins but not regular users"
    end

    permissions :index?, :show?, :edit?, :update?, :destroy? do
      it_behaves_like "forbids all"
    end
  end
end
