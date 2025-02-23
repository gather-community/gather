# frozen_string_literal: true

# Base job class.
class ApplicationJob < ActiveJob::Base
  queue_as :default

  # Our general approach to error handling in jobs is an opt-in approach to job retries.
  # So by default, if a job errors out, it will be reported to Sentry by the rescue_from
  # block below. If a particular job wants to retry on a given error, it can use the
  # retry_on handler. If all the retries fail, the exception will bubble up to here and
  # be reported to Sentry. The Sentry report will happen only after all retries fail, so
  # if observability of all errors is desired, they must be caught and reported manually.
  #
  # For retries, our standard best practice is to use:
  #     retry_on(ArgumentError, wait: :exponentially_longer) # default is 5 attempts
  #
  # Logging for the retry behavior can be seen in log/<environment>.log. The Delayed Job log
  # at log/delayed_job.log will always say "failed after 1 attempt" because the error only
  # is allowed to bubble up by ActiveJob on the final attempt. This is also why
  # max_attempts for Delayed Job is set to 1.
  #
  # The retry behavior described above has been tested manually and works.
  rescue_from StandardError, with: :rescue_from_exception

  protected

  def rescue_from_exception(exception)
    # We usually don't rescue from errors in dev or test mode because doing so makes it hard to see what
    # is failing when developing with the test server or doing test-driven development.
    # But in some case we may want to rescue in tests if we are testing the rescue behavior, so we
    # check an env var.
    if Rails.env.development? || (Rails.env.test? && ENV["RESCUE_FROM_JOB_EXCEPTIONS"].blank?)
      raise exception
    else
      Gather::ErrorReporter.instance.report(exception, data: {job: to_yaml})
    end
  end

  # Loads the specified object and sets up the cluster context. Assumes
  # the object is cluster-based and responds to `cluster`.
  # Specify either klass or class_name to indicate the class.
  # Specify either id or attribs to populate the object (the latter builds a new one)
  def with_object_in_cluster_context(klass: nil, class_name: nil, id: nil, attribs: nil)
    klass ||= class_name.constantize
    object = if id
               load_object_without_tenant(klass, id)
             else
               build_object_without_tenant(klass, attribs)
             end
    with_cluster(object.cluster) { yield(object) }
  end

  def load_object_without_tenant(klass, id)
    ActsAsTenant.without_tenant { klass.find(id).tap(&:cluster) }
  end

  def build_object_without_tenant(klass, attribs)
    ActsAsTenant.with_tenant(Cluster.find(attribs[:cluster_id])) { klass.new(attribs) }
  end

  def each_community(&block)
    Cluster.all.each do |cluster|
      with_cluster(cluster) do
        cluster.communities.each(&block)
      end
    end
  end

  # Sets tenant and timezone for the given cluster.
  def with_cluster(cluster, &block)
    ActsAsTenant.with_tenant(cluster) do
      with_cluster_timezone(cluster, &block)
    end
  end

  # Assumes all communities in the cluster have the same timezone.
  # If cluster has no communities, sets UTC.
  # The timezone setting should eventually move to the cluster model.
  # Also assumes the given cluster has been set as the current tenant.
  def with_cluster_timezone(cluster)
    community = cluster.communities[0]
    Time.zone = community ? community.settings.time_zone : "UTC"
    yield
  ensure
    Time.zone = "UTC"
  end

  # Assumes there is a community_id instance variable on the object.
  def community
    ActsAsTenant.without_tenant { Community.find(community_id) }
  end
end
