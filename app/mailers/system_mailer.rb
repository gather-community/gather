# frozen_string_literal: true

# System-level mailer for non-tenant-scoped notifications sent to internal addresses.
# Does not inherit ApplicationMailer to avoid subdomain/community requirements.
class SystemMailer < ActionMailer::Base # rubocop:disable Rails/ApplicationMailer
  default from: Settings.email.from

  def inactivity_warning_summary(communities)
    @communities = communities
    n = communities.size
    mail(
      to: "support@gather.coop",
      subject: "Final deletion warnings sent to #{n} #{"community".pluralize(n)}"
    )
  end

  def deletion_ready_notice(communities)
    @communities = communities
    n = communities.size
    mail(
      to: "support@gather.coop",
      subject: "#{n} #{"community".pluralize(n)} ready for deletion"
    )
  end
end
