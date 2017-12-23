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
          with_community_timezone(community) { yield(community) }
        end
      end
    end
  end

  # Sets tenant and timezone for the given community.
  def with_community(community)
    ActsAsTenant.with_tenant(community.cluster) do
      with_community_timezone(community) { yield }
    end
  end

  def with_community_timezone(community)
    begin
      Time.zone = community.settings.time_zone
      yield
    ensure
      Time.zone = "UTC"
    end
  end

  # Assumes there is a community_id instance variable on the object.
  def community
    ActsAsTenant.without_tenant { Community.find(community_id) }
  end
end
