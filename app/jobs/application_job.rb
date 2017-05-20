class ApplicationJob
  def error(job, exception)
    ExceptionNotifier.notify_exception(exception, data: nil)
  end

  def max_attempts
    1
  end

  protected

  def error_report_data
    nil
  end

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
