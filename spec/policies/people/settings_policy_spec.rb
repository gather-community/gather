# frozen_string_literal: true

require "rails_helper"

describe People::SettingsPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { community }

    permissions :index?, :show?, :edit?, :update? do
      it_behaves_like "permits admins but not regular users"
    end

    permissions :new?, :create?, :destroy? do
      it_behaves_like "forbids all"
    end
  end
end
