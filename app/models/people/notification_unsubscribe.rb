# frozen_string_literal: true

module People
  # Turns off one kind of notification for one user, from a signed token in an email's unsubscribe link.
  #
  # The token needs no sign-in, since mail clients' one-click unsubscribe (RFC 8058) POSTs it without a
  # session. It can only turn off the one notification it names, so a leaked token can't do much harm.
  # It doesn't expire, because people unsubscribe from old mail.
  class NotificationUnsubscribe
    PURPOSE = "notification_unsubscribe"

    attr_reader :user, :kind, :channel

    def self.token_for(user, kind, channel: :email)
      verifier.generate({"c" => user.cluster_id, "u" => user.id, "k" => kind.key.to_s, "ch" => channel.to_s},
        purpose: PURPOSE)
    end

    # Returns nil if the token is invalid, or names a user or kind that no longer exists.
    # Must be called with the tenant set; the token's cluster has to match it.
    def self.from_token(token)
      data = verifier.verified(token.to_s, purpose: PURPOSE)
      return nil unless data.is_a?(Hash) && data["c"] == ActsAsTenant.current_tenant&.id
      kind = NotificationCatalog::BY_KEY[data["k"].to_s.to_sym]
      channel = data["ch"].to_s.to_sym
      return nil unless kind&.configurable? && NotificationCatalog::CHANNELS.include?(channel)
      user = User.find_by(id: data["u"])
      return nil if user.nil?
      new(user: user, kind: kind, channel: channel)
    end

    def self.verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key(PURPOSE), url_safe: true, serializer: JSON
      )
    end

    def initialize(user:, kind:, channel:)
      @user = user
      @kind = kind
      @channel = channel
    end

    def already_off?
      !user.notification_enabled?(kind.key, channel: channel)
    end

    # Writes just this column, so that an unrelated validation problem on an old user record
    # can't stop a mail client's one-click unsubscribe from working.
    def perform!
      user.set_notification_pref(kind.key, false, channel: channel)
      user.update_columns(notification_prefs: user.notification_prefs, updated_at: Time.current)
    end
  end
end
