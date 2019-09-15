# frozen_string_literal: true

# Root mailer for all mailers.
class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  default from: Settings.email.from, reply_to: Settings.email.no_reply

  protected

  attr_reader :community

  # Overrides default mail method.
  #
  # Allows users or households in the `to` field.
  # It is up to the mailer system, not the background job system,
  # to figure out how to send mail to a household or user,
  # and whether users have opted out of a given type of mail.
  # Mails to households should be addressed to all the household users, not to each user separately.
  #
  # Also filters out fake users so that emails are not sent to their fake addresses.
  # Also filters out unconfirmed email addresses for security purposes (note that confirmation/password/
  # invite emails are sent with the AuthMailer which doesn't inherit from this class).
  #
  # If self.community returns a non-nil value, sets the appropriate subdomain.
  def mail(params)
    include_inactive = params.delete(:include_inactive) || false
    params[:to] = resolve_recipients(params[:to], include_inactive: include_inactive)
    return if params[:to].empty?
    raise "@community must be set or community method overridden to send mail" unless community
    with_community_subdomain(community) do
      super
    end
  end

  private

  def resolve_recipients(recipients, include_inactive:)
    Array.wrap(recipients).map do |recipient|
      if recipient.is_a?(User)
        resolve_user_email(recipient, include_inactive: include_inactive)
      elsif recipient.is_a?(Household)
        recipient.users.flat_map do |u|
          resolve_user_email(u, via_household: true, include_inactive: include_inactive)
        end
      else
        raise ArgumentError, "Invalid recipient type: #{recipient}"
      end
    end.flatten.uniq.compact
  end

  def resolve_user_email(user, include_inactive:, via_household: false)
    # It's ok to send emails to unconfirmed children because they can't log in, and children may still want
    # to get emails.
    # It would probably even be ok to send to unconfirmed adults but just to be safe we don't.
    # Inactive users may have blank emails, but if they do, they can't be confirmed,
    # so we exclude them anyway.
    if user.fake? || (user.adult? && !user.confirmed?) || (user.inactive? && !include_inactive)
      nil
    elsif user.child? && user.email.blank? && !via_household
      # We don't map emails to guardians if we're going via household because not all guardians
      # of children in a household live in that household. So sending an email addressed to household X
      # to guardians Y and Z of child C, even though Z doesn't live in household X, could be awkward.
      user.guardians.map(&:email)
    else
      user.email
    end
  end
end
