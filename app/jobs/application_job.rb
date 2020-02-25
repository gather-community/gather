# frozen_string_literal: true

# Base job class.
class ApplicationJob < ActiveJob::Base
  queue_as :default

  rescue_from(StandardError) do |exception|
    # We usually don't rescue from errors in test mode because doing so makes it hard to see what
    # is failing when doing TDD. But in some case we may want to rescue.
    raise exception if Rails.env.test? && ENV["RESCUE_FROM_JOB_EXCEPTIONS"].blank?
    ExceptionNotifier.notify_exception(exception, data: {job: to_yaml})
  end

  protected

  # Loads the specified object and sets up the cluster context. Assumes
  # the class is cluster-based and responds to `cluster`.
  def with_object_in_cluster_context(class_or_class_name, id)
    klass = class_or_class_name.is_a?(String) ? class_or_class_name.constantize : class_or_class_name
    object = load_object_without_tenant(klass, id)
    with_cluster(object.cluster) { yield(object) }
  end

  def load_object_without_tenant(klass, id)
    ActsAsTenant.without_tenant { klass.find(id).tap(&:cluster) }
  end

  def each_community
    Cluster.all.each do |cluster|
      with_cluster(cluster) do
        cluster.communities.each { |cmty| yield(cmty) }
      end
    end
  end

  # Sets tenant and timezone for the given cluster.
  def with_cluster(cluster)
    ActsAsTenant.with_tenant(cluster) do
      with_cluster_timezone(cluster) { yield }
    end
  end

  # Assumes all communities in the cluster have the same timezone.
  # The timezone setting should eventually move to the cluster model.
  # Also assumes the given cluster has been set as the current tenant.
  def with_cluster_timezone(cluster)
    Time.zone = cluster.communities[0].settings.time_zone
    yield
  ensure
    Time.zone = "UTC"
  end

  # Assumes there is a community_id instance variable on the object.
  def community
    ActsAsTenant.without_tenant { Community.find(community_id) }
  end
end
