class ApplicationJob
  def error(job, exception)
    ExceptionNotifier.notify_exception(exception, data: {job: to_yaml})
  end

  def max_attempts
    1
  end

  protected

  def each_community
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        cluster.communities.each do |community|
          begin
            Time.zone = community.settings.time_zone
            yield(community)
          ensure
            Time.zone = "UTC"
          end
        end
      end
    end
  end

  # Not all jobs will need this, but this is a useful method if they do.
  def with_tenant_from_community_id(community_id)
    community = ActsAsTenant.without_tenant { Community.find(community_id) }
    ActsAsTenant.with_tenant(community.cluster) { yield }
  end
end
