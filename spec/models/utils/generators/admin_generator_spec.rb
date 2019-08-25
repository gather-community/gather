# frozen_string_literal: true

require "rails_helper"

describe Utils::Generators::AdminGenerator, :without_tenant, :dont_delay_jobs do
  let(:cluster) { create(:cluster) }
  let!(:community) { ActsAsTenant.with_tenant(cluster) { create(:community) } }
  let(:admin) do
    described_class.new(cluster: cluster, email: "admin@example.com", first_name: "John",
                        last_name: "Doe", super_admin: super_admin).generate
  end

  context "super admin" do
    let(:super_admin) { true }

    it "should return user with password exposed" do
      # admin generation should handle its own tenant setting so do it outside of block
      expect(admin.roles.map(&:name)).to include("super_admin")
      ActsAsTenant.with_tenant(cluster) do
        expect(admin.password).not_to be_blank
        expect(admin).to be_confirmed
        expect(User.with_role(:admin).count).to eq(0)
        expect(User.with_role(:super_admin).count).to eq(1)
      end
    end
  end

  context "regular admin" do
    let(:super_admin) { false }

    it "should send invite" do
      # admin generation should handle its own tenant setting so do it outside of block
      expect { admin }.to change { ActionMailer::Base.deliveries.size }.by(1)
      ActsAsTenant.with_tenant(cluster) do
        expect(ActionMailer::Base.deliveries.last.subject).to eq("Instructions for Signing in to Gather")
        expect(admin.roles.map(&:name)).not_to include("super_admin")
        expect(admin).not_to be_confirmed
        expect(User.with_role(:admin).count).to eq(1)
        expect(User.with_role(:super_admin).count).to eq(0)
      end
    end
  end
end
