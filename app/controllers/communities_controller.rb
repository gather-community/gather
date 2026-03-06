# frozen_string_literal: true

class CommunitiesController < ApplicationController
  decorates_assigned :communities, :community

  def index
    authorize(sample_community)
    @communities = Utils::CommunitySummarizer.new.communities(policy_scope(Community))
  end

  def show
    load_community
    authorize(@community)
    @community.subscription&.populate
  rescue Stripe::InvalidRequestError
    @subscription_stripe_error = true
  end

  def destroy
    load_community
    authorize(@community)
    CommunityDeletionJob.perform_later(@community.id)
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
