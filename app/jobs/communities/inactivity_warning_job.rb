# frozen_string_literal: true

module Communities
  class InactivityWarningJob < ApplicationJob
    INACTIVITY_THRESHOLD = 90.days
    WARNING_INTERVAL = 7.days
    MAX_WARNINGS = 3
    PROTECTED_SLUGS = %w[staff demo].freeze

    def perform
      third_warning_communities = []
      deletion_ready_communities = []
      each_community do |community|
        process_community(community, third_warning_communities, deletion_ready_communities)
      end
      SystemMailer.inactivity_warning_summary(third_warning_communities).deliver_now \
        if third_warning_communities.any?
      SystemMailer.deletion_ready_notice(deletion_ready_communities).deliver_now \
        if deletion_ready_communities.any?
    end

    private

    def process_community(community, third_warning_communities, deletion_ready_communities)
      return if PROTECTED_SLUGS.include?(community.slug)
      return if active_subscription?(community)

      if community.inactive?
        renotify_if_due(community, deletion_ready_communities)
        return
      end

      last_login_at = last_login_for(community)
      return if reset_if_logged_in(community, last_login_at)

      effective_last_active = last_login_at || community.created_at
      return if effective_last_active >= INACTIVITY_THRESHOLD.ago

      advance_warning_state(community, last_login_at, third_warning_communities, deletion_ready_communities)
    end

    def renotify_if_due(community, deletion_ready_communities)
      sent_at = community.inactivity_warning_sent_at
      return unless sent_at.nil? || sent_at < WARNING_INTERVAL.ago
      deletion_ready_communities << community
      community.update!(inactivity_warning_sent_at: Time.current)
    end

    def reset_if_logged_in(community, last_login_at)
      return false unless community.inactivity_warning_count > 0
      return false unless last_login_at.present? && last_login_at > community.inactivity_warning_sent_at
      community.update!(inactivity_warning_count: 0, inactivity_warning_sent_at: nil)
      true
    end

    def advance_warning_state(community, last_login_at, third_warning_communities, deletion_ready_communities)
      warning_count = community.inactivity_warning_count

      if warning_count == 0
        send_warning(community, 1, last_login_at)
        community.update!(inactivity_warning_count: 1, inactivity_warning_sent_at: Time.current)
      elsif warning_count < MAX_WARNINGS && community.inactivity_warning_sent_at < WARNING_INTERVAL.ago
        advance_mid_warning(community, warning_count, last_login_at, third_warning_communities)
      elsif warning_count == MAX_WARNINGS && community.inactivity_warning_sent_at < WARNING_INTERVAL.ago
        community.deactivate
        community.update!(inactivity_warning_sent_at: Time.current)
        deletion_ready_communities << community
      end
    end

    def advance_mid_warning(community, warning_count, last_login_at, third_warning_communities)
      next_count = warning_count + 1
      send_warning(community, next_count, last_login_at)
      community.update!(inactivity_warning_count: next_count, inactivity_warning_sent_at: Time.current)
      third_warning_communities << community if next_count == MAX_WARNINGS
    end

    def active_subscription?(community)
      sub = community.subscription
      return false if sub.nil?
      sub.populate
      sub.active?
    rescue Stripe::StripeError => e
      Gather::ErrorReporter.instance.report(e,
        data: {community_id: community.id, community_name: community.name})
      true
    end

    def last_login_for(community)
      User.joins(:household)
        .where(households: {community_id: community.id}, fake: false)
        .maximum(:last_sign_in_at)
    end

    def send_warning(community, warning_count, last_login_at)
      admins = User.with_role(:admin, community).active
      Communities::InactivityMailer.warning(community, warning_count, last_login_at, admins).deliver_now
    end
  end
end
