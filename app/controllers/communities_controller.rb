# frozen_string_literal: true

class CommunitiesController < ApplicationController
  decorates_assigned :communities, :community

  def index
    authorize(sample_community)
    prepare_lenses(:"communities/status")
    communities = Utils::CommunitySummarizer.new.communities(policy_scope(Community))
    @communities = if lenses[:status].active?
      communities.select { |c| c.status == lenses[:status].selection }
    else
      communities
    end
  end

  def admin
    load_community
    authorize(@community)
    @community.subscription&.sync!
    @subscription_stripe_error = @community.subscription&.sync_error.present?
  end

  def resync_all
    authorize(sample_community, :index?)
    Subscription::SyncAllJob.perform_later
    redirect_to(communities_path, notice: "Subscription resync started. Refresh in a minute to see updates.")
  end

  def destroy
    load_community
    authorize(@community)
    if params[:community_slug] != @community.slug
      redirect_to(admin_community_path(@community), alert: "Incorrect slug. Community was not deleted.")
      return
    end
    CommunityDeletionJob.perform_later(@community.id, current_user.id)
    redirect_to(communities_path, notice: "#{@community.name} is being deleted.")
  end

  protected

  def apex_domain_only
    true
  end

  private

  def load_community
    ActsAsTenant.without_tenant do
      @community = Community.includes(:cluster, :subscription, :subscription_intent).find(params[:id])
    end
  end

  def sample_community
    Community.new
  end
end
