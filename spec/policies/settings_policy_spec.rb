# frozen_string_literal: true

require "rails_helper"

describe SettingsPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { community }

    permissions :index?, :show?, :edit?, :update?, :show_sso_secret?, :reset_sso_secret? do
      it_behaves_like "permits admins but not regular users"
    end

    permissions :new?, :create?, :destroy? do
      it_behaves_like "forbids all"
    end
  end
end
