class ApplicationMailer < ActionMailer::Base
  include SubdomainSettable
  default from: Settings.email.from

  protected

  # Overrides default mail method.
  # Allows email addresses, users, or households in the to field.
  # If community returns a non-nil value, sets the appropriate subdomain.
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
        recipient.email
      elsif recipient.is_a?(Household)
        recipient.users.map(&:email)
      else
        recipient
      end
    end.flatten.compact
  end
end
