# frozen_string_literal: true

class CommunitiesController < ApplicationController
  decorates_assigned :communities

  def index
    authorize(sample_community)
    @communities = ActsAsTenant.without_tenant { query.to_a }
  end

  private

  def query
    time_expr = "communities.created_at + '5 minutes'::interval"
    policy_scope(Community)
      .select("
        communities.*,
        (SELECT COUNT(u.id) FROM users u INNER JOIN households h ON h.id = u.household_id
          WHERE h.community_id = communities.id AND u.fake = 'f') AS user_count,
        (SELECT COUNT(m.id) FROM meals m
          WHERE m.community_id = communities.id AND m.created_at > #{time_expr}) AS meal_count,
        (SELECT NOW() - MAX(m.served_at) FROM meals m
          WHERE m.community_id = communities.id AND m.created_at > #{time_expr}) AS last_meal_age")
      .by_name
  end

  def sample_community
    Community.new
  end
end
