# frozen_string_literal: true

# Root mailer for all mailers.
class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  include RecipientLocale
  default from: Settings.email.from, reply_to: Settings.email.from
  layout "mailer"

  # Sends each recipient their own message. Configurable notifications must be sent this way, because
  # each carries an unsubscribe link that works for one person only (see `mail`).
  # Pass the mailer action and its arguments, e.g. `MealMailer.deliver_per_recipient(:meal_reminder, signup)`.
  # Returns the delivered messages.
  #
  # If a delivery fails, the remaining recipients still get theirs, and then the first error is
  # re-raised so the caller can report it as usual.
  def self.deliver_per_recipient(action, ...)
    emails = with(listing_recipients: true).public_send(action, ...).message.to
    errors = []
    messages = Array.wrap(emails).filter_map do |email|
      with(recipient_email: email).public_send(action, ...).deliver_now
    rescue => e
      errors << e
      nil
    end
    raise errors.first if errors.any?
    messages
  end

  protected

  attr_reader :community

  # Overrides default mail method.
  #
  # Allows strings, users, or households in the `to` field.
  # It is up to the mailer system, not the background job system,
  # to figure out how to send mail to a household or user,
  # and whether users have opted out of a given type of mail.
  # Mails to households should be addressed to all the household users, not to each user separately.
  #
  # Also filters out users who have turned off this kind of notification. The kind comes from
  # People::NotificationCatalog, looked up by mailer action unless passed as `notification:`.
  # Raises if the action isn't in the catalog, so every email has to be accounted for on the
  # notification preferences page.
  #
  # Also filters out fake users so that emails are not sent to their fake addresses.
  # Also filters out unconfirmed email addresses for security purposes (note that confirmation/password/
  # invite emails are sent with the AuthMailer which doesn't inherit from this class).
  #
  # Mail to community members gets a footer linking to the notification settings page (see the mailer
  # layout). Configurable notifications also get RFC 8058 List-Unsubscribe headers for one-click unsubscribe.
  # The link turns the notification off for one person, so these messages must go to exactly one
  # recipient. Use `deliver_per_recipient`, which sends each recipient their own copy.
  #
  # If self.community returns a non-nil value, sets the appropriate subdomain.
  def mail(params)
    include_inactive = params.delete(:include_inactive)
    kind = notification_kind(params.delete(:notification))
    recipients = resolve_recipients(params[:to], include_inactive: include_inactive, kind: kind)
    return if recipients.empty?
    raise "@community must be set or community method overridden to send mail" unless community

    if kind.configurable?
      # Just report who would get it, without rendering. deliver_per_recipient reads this back.
      if mailer_params[:listing_recipients]
        return super(to: recipient_emails(recipients), subject: "", body: "")
      end
      recipients = select_single_recipient(recipients)
      return if recipients.empty?
    end

    params[:to] = recipient_emails(recipients)
    with_community_subdomain(community) do
      @notification_preferences_url = notification_preferences_url if settings_footer?(recipients, kind)
      add_unsubscribe(recipients.first, kind) if kind.configurable? && recipients.first.is_a?(User)
      super
    end
  end

  private

  # The mailer's `params`, set by `with`. Named differently because `mail` takes an argument called params.
  def mailer_params
    params || {}
  end

  def recipient_emails(recipients)
    recipients.map { |r| r.is_a?(User) ? r.email : r }.uniq
  end

  def select_single_recipient(recipients)
    if (email = mailer_params[:recipient_email])
      recipients = recipients.select { |r| (r.is_a?(User) ? r.email : r) == email }.first(1)
    end
    if recipient_emails(recipients).size > 1
      raise ArgumentError, "#{self.class.name}##{action_name} is a configurable notification with " \
        "several recipients. Send it with deliver_per_recipient so each gets their own unsubscribe link."
    end
    recipients
  end

  # Whether the layout should add the footer linking to the notification settings page.
  # Internal mail doesn't go to members, and users without full access can't sign in to reach the page.
  # (They can still unsubscribe from configurable mail with their mail client's one-click button.)
  def settings_footer?(recipients, kind)
    kind.type != :internal && recipients.any? { |r| r.is_a?(User) && r.full_access? }
  end

  # Called inside with_community_subdomain so URLs point at the right community.
  def add_unsubscribe(user, kind)
    token = People::NotificationUnsubscribe.token_for(user, kind)
    headers["List-Unsubscribe"] = "<#{notification_unsubscribe_url(token: token)}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end

  def notification_kind(key)
    return People::NotificationCatalog.find(key) if key
    People::NotificationCatalog.for_mailer_action(self.class, action_name) ||
      raise("#{self.class.name}##{action_name} must be listed in People::NotificationCatalog")
  end

  def resolve_recipients(recipients, include_inactive:, kind:)
    users_or_strings = Array.wrap(recipients).map do |recipient|
      if recipient.is_a?(User)
        resolve_user(recipient)
      elsif recipient.is_a?(Household)
        recipient.users.flat_map do |u|
          resolve_user(u, via_household: true)
        end
      elsif recipient.is_a?(String)
        # Convert any empty strings to nil so they'll get removed.
        recipient.presence
      else
        raise ArgumentError, "Invalid recipient type: #{recipient}"
      end
    end.flatten.uniq.compact

    users_or_strings = if include_inactive == :always
      users_or_strings
    elsif include_inactive == :if_no_active
      # If all results are inactive users, send to all. Else just send to active users and raw email addresses.
      inactive_users, active_users_or_strings = users_or_strings.partition { |us| us.is_a?(User) && us.inactive? }
      emails = if active_users_or_strings.empty?
        inactive_users
      else
        active_users_or_strings
      end
    else
      users_or_strings.reject { |us| us.is_a?(User) && us.inactive? }
    end

    # This comes after the inactive logic so that an active user opting out doesn't cause
    # mail to go to inactive users instead.
    users_or_strings.reject { |us| us.is_a?(User) && !us.notification_enabled?(kind.key) }
  end

  def resolve_user(user, via_household: false)
    # For children with no emails, we send to their guardians, except
    # we don't map emails to guardians if we're going via household because not all guardians
    # of children in a household live in that household. So sending an email addressed to household X
    # to guardians Y and Z of child C, even though Z doesn't live in household X, could be awkward.
    users = if user.child? && user.email.blank? && !via_household
      user.guardians
    else
      [user]
    end

    # Don't send to fake users or unconfirmed full_access users.
    # It's ok to send emails to unconfirmed non-full_access users
    # because they can't log in, and they may still want to get emails.
    # It would probably even be ok to send to unconfirmed full_access users but just to be safe we don't.
    users.reject { |u| u.email.blank? || u.fake? || (u.full_access? && !u.confirmed?) }
  end
end
