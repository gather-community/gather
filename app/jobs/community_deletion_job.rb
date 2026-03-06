# frozen_string_literal: true

class CommunityDeletionJob < ApplicationJob
  def perform(community_id)
    with_object_in_cluster_context(klass: Community, id: community_id) do |community|
      community.destroy!
    end
  end
end
