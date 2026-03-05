# frozen_string_literal: true

require "rails_helper"

describe Communities::SignupApprovalJob do
  include_context "jobs"

  let!(:signup) { create(:communities_signup, :approved, want_sample_data: false) }

  subject(:job) { described_class.new(signup.id) }

  it "provisions cluster, community, and admin user, updates status, and sends emails" do
    expect(Communities::SignupMailer).to receive(:application_approved).with(signup).and_call_original
    expect(Communities::SignupMailer).to receive(:approval_created).with(signup).and_call_original

    perform_job

    expect(signup.reload.status).to eq("created")

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

  context "when generation fails" do
    before do
      allow(Utils::Generators::MainGenerator).to receive(:new).and_raise(RuntimeError, "DB connection failed")
    end

    it "marks signup as failed, emails the reviewer, and re-raises" do
      expect(Communities::SignupMailer).to receive(:approval_failed).with(signup).and_call_original
      expect { perform_job }.to raise_error(RuntimeError, "DB connection failed")
      expect(signup.reload.status).to eq("failed")
      expect(signup.reload.failure_message).to eq("DB connection failed")
    end
  end
end
