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

  # Loads the specified object and sets up the community context. Assumes
  # the class is cluster-based and responds to `community`.
  def with_object_in_community_context(class_or_class_name, id)
    klass = class_or_class_name.is_a?(String) ? class_or_class_name.constantize : class_or_class_name

    # Load the object and call community while still inside the
    # without_tenant block to preload the association.
    # Else we get a no tenant error when calling community later.
    object = ActsAsTenant.without_tenant { klass.find(id).tap(&:community) }

    with_community(object.community) { yield(object) }
  end

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
    Time.zone = community.settings.time_zone
    yield
  ensure
    Time.zone = "UTC"
  end

  # Assumes there is a community_id instance variable on the object.
  def community
    ActsAsTenant.without_tenant { Community.find(community_id) }
  end
end
