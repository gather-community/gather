class ApplicationJob
  def error(job, exception)
    ExceptionNotifier.notify_exception(exception)
  end

  protected

  def each_community
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        cluster.communities.each do |community|
          yield(community)
        end
      end
    end
  end
end
