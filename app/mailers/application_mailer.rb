# frozen_string_literal: true

# Root mailer for all mailers.
class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  include RecipientLocale
  default from: Settings.email.from, reply_to: Settings.email.from
  layout "mailer"

  # RFC 8058 header value, not user-facing text.
  ONE_CLICK_UNSUBSCRIBE = "List-Unsubscribe=One-Click" # rubocop:disable Gather/HardCodedString

  protected

  attr_reader :community

  # The person a configurable notification is for, passed as `SomeMailer.with(recipient: user)`.
  # Callers work out recipients with Notifications::Recipients and send each their own message.
  def recipient
    params&.dig(:recipient) ||
      raise(ArgumentError, "Send #{self.class.name}##{action_name} with .with(recipient: user)")
  end

  # Overrides default mail method.
  #
  # Every mailer action is a kind of notification in Notifications::Catalog, looked up by mailer action
  # unless passed as `notification:`. Raises if the action isn't listed, so every email has to be
  # accounted for on the notification preferences page.
  #
  # The `to` field can hold users, households, or email addresses. Notifications::Recipients turns them into
  # the people who should actually get the email: households become their members, children without email
  # become their guardians, and fake, inactive and opted-out users are dropped. A household's members all
  # go on the one message.
  #
  # Configurable notifications must go to exactly one user, because they carry a one-click unsubscribe
  # header (RFC 8058) that works for one person. Callers resolve recipients themselves and loop, passing
  # each with `with(recipient:)`. Resolving here again is a safety net: it can't email someone who
  # opted out even if a caller skipped the resolver.
  #
  # Mail to community members gets a footer linking to the notification settings page (see the mailer
  # layout).
  #
  # If self.community returns a non-nil value, sets the appropriate subdomain.
  def mail(params)
    kind = notification_kind(params.delete(:notification))
    recipients = Notifications::Recipients.resolve(params[:to], kind: kind)
    return if recipients.empty?
    raise "@community must be set or community method overridden to send mail" unless community
    assert_single_user(recipients) if kind.configurable?

    params[:to] = recipients.map { |r| r.is_a?(User) ? r.email : r }.uniq
    with_community_subdomain(community) do
      @notification_preferences_url = notification_preferences_url if settings_footer?(recipients, kind)
      add_unsubscribe(recipients.first, kind) if kind.configurable?
      super
    end
  end

  private

  def notification_kind(key)
    return Notifications::Catalog.find(key) if key
    Notifications::Catalog.for_mailer_action(self.class, action_name) ||
      raise("#{self.class.name}##{action_name} must be listed in Notifications::Catalog")
  end

  def assert_single_user(recipients)
    return if recipients.size == 1 && recipients.first.is_a?(User)
    raise ArgumentError, "#{self.class.name}##{action_name} is a configurable notification, so it must " \
      "go to one user. Resolve recipients with Notifications::Recipients and send each their own message."
  end

  # Whether the layout should add the footer linking to the notification settings page.
  # Internal mail doesn't go to members, and users without full access can't sign in to reach the page.
  # (They can still unsubscribe from configurable mail with their mail client's one-click button.)
  def settings_footer?(recipients, kind)
    kind.type != :internal && recipients.any? { |r| r.is_a?(User) && r.full_access? }
  end

  # Called inside with_community_subdomain so URLs point at the right community.
  def add_unsubscribe(user, kind)
    token = Notifications::Unsubscribe.token_for(user, kind)
    headers["List-Unsubscribe"] = "<#{notification_unsubscribe_url(token: token)}>"
    headers["List-Unsubscribe-Post"] = ONE_CLICK_UNSUBSCRIBE
  end
end
