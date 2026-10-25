# frozen_string_literal: true

# == Schema Information
#
# Table name: mail_migration_domain_checks
#
#  id         :bigint           not null, primary key
#  checked_at :datetime         not null
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  data       :jsonb            not null
#  domain_id  :bigint           not null
#  updated_at :datetime         not null
#
module MailMigration
  # The stored result of the most recent mail migration check for one domain, written by
  # RefreshJob (via Checker) and read by the mail migration page. `data` holds:
  #   mx                 — [[preference, exchange], ...] as found in DNS
  #   spf                — the domain's SPF record string, or nil
  #   smtp2go_status     — "verified" / "pending" / "not_added", or "unknown" when the SMTP2GO
  #                        API couldn't be queried at check time
  #   validation_records — [{kind:, host:, target:, verified:, in_dns:}, ...] for the CNAMEs
  #                        SMTP2GO requires (empty unless the domain is on the SMTP2GO account)
  class DomainCheck < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :domain, inverse_of: :mail_migration_check
  end
end
