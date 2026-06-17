# frozen_string_literal: true

require "rails_helper"

describe SearchPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:record) { :search }

    permissions :index? do
      it_behaves_like "permits active users only"
    end
  end
end
