class DeviseMailer < Devise::Mailer
  include SubdomainSettable

  def reset_password_instructions(record, token, opts = {})
    with_community_subdomain(record.community) do
      super.tap do |mail|
        mail.subject = "Welcome to Gather!"
      end
    end
  end
end
