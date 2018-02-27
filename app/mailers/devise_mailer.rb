class DeviseMailer < Devise::Mailer
  include SubdomainSettable

  def reset_password_instructions(user, token, opts = {})
    with_community_subdomain(user.community) do
      return if user.fake?
      super.tap do |mail|
        mail.subject = "Welcome to Gather!"
      end
    end
  end
end
