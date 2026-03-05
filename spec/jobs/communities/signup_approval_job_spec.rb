# frozen_string_literal: true

require "rails_helper"

describe Communities::SignupApprovalJob do
  include_context "jobs"

  let!(:signup) { create(:communities_signup, want_sample_data: false) }

  subject(:job) { described_class.new(signup.id) }

  it "provisions cluster, community, and admin user and sends approval email" do
    expect(Communities::SignupMailer).to receive(:application_approved).with(signup).and_return(mlrdbl)

    perform_job

    cluster = ActsAsTenant.without_tenant { Cluster.find_by(name: signup.community_name) }
    expect(cluster).to be_present

    ActsAsTenant.with_tenant(cluster) do
      community = Community.find_by(name: signup.community_name)
      expect(community).to be_present
      expect(community.slug).to eq(signup.slug)
      expect(community.settings.time_zone).to eq(signup.time_zone)

      user = User.find_by(email: signup.contact_email)
      expect(user).to be_present
      expect(user).to have_role(:admin)
    end
  end
end
