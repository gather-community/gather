class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  default from: Settings.email.from

  protected

  # Overrides default mail method.
  #
  # Allows email addresses, users, or households in the to field.
  # It is up to the mailer system, not the job system, to figure out how to send mail to a household or user,
  # and whether users have opted out of a given type of mail.
  # Mails to households should be addressed to all the household users, not to each user separately.
  #
  # Also filters out fake users so that emails are not sent to their fake addresses.
  #
  # If self.community returns a non-nil value, sets the appropriate subdomain.
  def mail(params)
    params[:to] = resolve_recipients(params[:to])
    return if params[:to].empty?
    with_community_subdomain(community) do
      super
    end
  end

  def community
    nil
  end

  private

  def resolve_recipients(recipients)
    Array.wrap(recipients).map do |recipient|
      if recipient.is_a?(User)
        recipient.fake? ? nil : recipient.email
      elsif recipient.is_a?(Household)
        recipient.users.reject(&:fake?).map(&:email)
      else
        recipient
      end
    end.flatten.compact
  end
end
