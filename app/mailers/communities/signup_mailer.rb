# frozen_string_literal: true

# WARNING: This class does not subclass ApplicationMailer so it doesn't inherit things like:
# - Default from address
# - Subdomain logic
# - Filtering of unconfirmed/fake users
#
# It is used for community signup notifications which are not tenant-scoped.
class Communities::SignupMailer < ActionMailer::Base
  include RecipientLocale
  default from: Settings.email.from

  def notify_approvers(signup)
    @signup = signup
    @review_url = review_communities_signup_url(@signup, host: Settings.url.host)
    approver_emails = ActsAsTenant.without_tenant do
      User.with_role(:new_community_approver).pluck(:email).compact
    end
    return if approver_emails.empty?
    # Goes only to Gather staff, so it isn't translated.
    subject = "New community signup: #{signup.community_name}" # rubocop:disable Gather/HardCodedString
    mail(to: approver_emails, subject: subject)
  end

  def application_approved(signup)
    @signup = signup
    # reviewed_by is a User, which is tenant-scoped, so look it up without tenant.
    approver_name = ActsAsTenant.without_tenant { signup.reviewed_by.name }
    mail(to: signup.contact_email,
      subject: t("communities.signup_mailer.application_approved.subject", approver: approver_name))
  end

  def application_denied(signup)
    @signup = signup
    mail(to: signup.contact_email, subject: t("communities.signup_mailer.application_denied.subject"))
  end

  def approval_created(signup)
    @signup = signup
    @signup_url = review_communities_signup_url(signup, host: Settings.url.host)
    # reviewed_by is a User, which is tenant-scoped, so look it up without tenant.
    reviewer_email = ActsAsTenant.without_tenant { signup.reviewed_by.email }
    # Goes only to Gather staff, so it isn't translated.
    subject = "Community setup complete: #{signup.community_name}" # rubocop:disable Gather/HardCodedString
    mail(to: reviewer_email, subject: subject)
  end

  def approval_failed(signup)
    @signup = signup
    @signup_url = review_communities_signup_url(signup, host: Settings.url.host)
    # reviewed_by is a User, which is tenant-scoped, so look it up without tenant.
    reviewer_email = ActsAsTenant.without_tenant { signup.reviewed_by.email }
    # Goes only to Gather staff, so it isn't translated.
    subject = "Community setup FAILED: #{signup.community_name}" # rubocop:disable Gather/HardCodedString
    mail(to: reviewer_email, subject: subject)
  end
end
