# frozen_string_literal: true

require "rails_helper"

describe "communities request" do
  let!(:actor) { create(:super_admin) }
  let!(:community) { create(:community, slug: "target-coho") }

  before do
    use_apex_domain
    sign_in(actor)
  end

  describe "index" do
    it "renders the detailed subscription status and derived community status" do
      create(:subscription, community: community, stripe_status: "past_due", synced_at: Time.current)
      get communities_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Past due") # detailed subscription label
      expect(response.body).to include("Problem")  # derived community status label
    end
  end

  describe "resync_all" do
    it "enqueues the sync-all job and redirects to the index" do
      expect do
        post resync_all_communities_path
      end.to have_enqueued_job(Subscription::SyncAllJob)
      expect(response).to redirect_to(communities_path)
    end
  end

  describe "activate" do
    it "reactivates the community and redirects to the admin page" do
      community.update!(deactivated_at: Time.current, inactivity_warning_count: 3)
      put activate_community_path(community)
      expect(response).to redirect_to(admin_community_path(community))
      expect(community.reload).to be_active
      expect(community.inactivity_warning_count).to eq(0)
    end

    context "as a non-super-admin" do
      let!(:actor) { create(:admin) }

      it "is denied and leaves the community deactivated" do
        community.update!(deactivated_at: Time.current)
        expect do
          put activate_community_path(community)
        end.to raise_error(Pundit::NotAuthorizedError)
        expect(community.reload).to be_inactive
      end
    end
  end

  describe "destroy" do
    context "with wrong confirmation" do
      it "redirects back with alert and does not enqueue job" do
        expect do
          delete community_path(community), params: {confirmation: "wrong-slug"}
        end.not_to have_enqueued_job(CommunityDeletionJob)
        expect(response).to redirect_to(admin_community_path(community))
        expect(flash[:alert]).to eq("Incorrect slug. Community was not deleted.")
      end
    end

    context "with correct confirmation" do
      it "enqueues job with community and actor ids and redirects" do
        expect do
          delete community_path(community), params: {confirmation: community.slug}
        end.to have_enqueued_job(CommunityDeletionJob).with(community.id, actor.id)
        expect(response).to redirect_to(communities_path)
      end
    end
  end
end
