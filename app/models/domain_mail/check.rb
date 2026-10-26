# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_mail_checks
#
#  id         :bigint           not null, primary key
#  checked_at :datetime         not null
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  data       :jsonb            not null
#  domain_id  :bigint           not null
#  updated_at :datetime         not null
#
module DomainMail
  # The stored result of the most recent mail check for one domain, written by Checker and read
  # by the admin domains dashboard. `data` holds:
  #   mx                 — [[preference, exchange], ...] as found in DNS
  #   spf                — the domain's SPF record string, or nil
  #   spf_lookup_terms   — the DNS-querying terms the SPF record uses, recursively (see
  #                        SpfLookupCounter); more than 10 breaks SPF per RFC 7208
  #   smtp2go_status     — "verified" / "pending" / "not_added", or "unknown" when the SMTP2GO
  #                        API couldn't be queried at check time
  #   validation_records — [{kind:, host:, target:, actual:, verified:, in_dns:}, ...] for the
  #                        CNAMEs SMTP2GO requires (empty unless the domain is on the SMTP2GO
  #                        account); actual is the CNAME value we found in DNS, if any
  class Check < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :domain, inverse_of: :mail_check
  end
end
