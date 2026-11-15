# frozen_string_literal: true

require "rails_helper"

describe Admin::DomainPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { %i[admin domain] }

    permissions :index? do
      it "permits super admins only" do
        expect(subject).to permit(super_admin, record)
        expect(subject).not_to permit(cluster_admin, record)
        expect(subject).not_to permit(admin, record)
        expect(subject).not_to permit(user, record)
      end
    end
  end
end
