# frozen_string_literal: true

module Communities
  class InactivityMailer < ApplicationMailer
    def warning(community, warning_count, last_login_at, admins)
      @community = community
      @warning_count = warning_count
      @last_login_at = last_login_at
      @is_final = warning_count == Communities::InactivityWarningJob::MAX_WARNINGS
      recipients = admins.present? ? admins.to_a : ["support@gather.coop"]
      subject = if @is_final
        t("communities.inactivity_mailer.warning.subject_final", community: community.name)
      else
        t("communities.inactivity_mailer.warning.subject", community: community.name)
      end
      mail(to: recipients, subject: subject)
    end
  end
end
