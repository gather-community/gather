# frozen_string_literal: true

class CommunityDeletionJob < ApplicationJob
  def perform(community_id, actor_id)
    actor = ActsAsTenant.without_tenant { User.find(actor_id) }
    raise "Actor #{actor_id} is no longer a super_admin; aborting deletion of community #{community_id}" \
      unless actor.global_role?(:super_admin)
    with_object_in_cluster_context(klass: Community, id: community_id) do |community|
      Rails.logger.info("CommunityDeletionJob: deleting #{community.name} (id=#{community.id}) " \
                        "triggered by #{actor.email} (id=#{actor_id})")
      community.destroy!
    end
  end
end
