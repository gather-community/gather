# frozen_string_literal: true

require "rails_helper"

describe CommunityDeletionJob do
  include_context "jobs"

  let!(:actor) { create(:super_admin) }
  let!(:community) { Defaults.community }

  subject(:job) { described_class.new(community.id, actor.id) }

  context "when actor is still a super_admin" do
    it "destroys the community and logs" do
      allow(Rails.logger).to receive(:info)
      perform_job
      expect(Rails.logger).to have_received(:info).with(/CommunityDeletionJob.*#{community.name}.*#{actor.email}/)
      expect(Community.exists?(community.id)).to be(false)
    end
  end

  context "when actor is no longer a super_admin" do
    before { actor.remove_role(:super_admin) }

    it "raises without destroying the community" do
      expect { perform_job }.to raise_error(RuntimeError, /no longer a super_admin/)
      expect(Community.exists?(community.id)).to be(true)
    end
  end
end
