# frozen_string_literal: true

class CommunitiesController < ApplicationController
  decorates_assigned :communities

  def index
    authorize(sample_community)
    @communities = Utils::CommunitySummarizer.new.communities(policy_scope(Community))
  end

  protected

  def apex_domain_only
    true
  end

  private

  def sample_community
    Community.new
  end
end
