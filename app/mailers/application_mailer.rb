# frozen_string_literal: true

# Root mailer for all mailers.
class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  include RecipientLocale
  default from: Settings.email.from, reply_to: Settings.email.from
  helper :money

  # Lets views and helpers shared with the web app, e.g. format_money, find the community.
  helper_method :current_community

  protected

  attr_reader :community

  # Protected so it isn't taken for a mailer action.
  def current_community
    community
  end

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
  # If self.community returns a non-nil value, sets the appropriate subdomain.
  def mail(params)
    include_inactive = params.delete(:include_inactive)
    kind = notification_kind(params.delete(:notification))
    params[:to] = resolve_recipients(params[:to], include_inactive: include_inactive, kind: kind)
    return if params[:to].empty?
    raise "@community must be set or community method overridden to send mail" unless community
    with_community_subdomain(community) do
      super
    end
  end

  private

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
    users_or_strings = users_or_strings.reject { |us| us.is_a?(User) && !us.notification_enabled?(kind.key) }

    users_or_strings.map { |us| us.is_a?(User) ? us.email : us }
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
