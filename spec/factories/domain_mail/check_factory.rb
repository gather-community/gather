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
FactoryBot.define do
  factory :domain_mail_check, class: "DomainMail::Check" do
    domain
    checked_at { Time.current }
    data do
      {
        "mx" => [[10, "mail.gather.coop"], [20, "mail2.gather.coop"]],
        "spf" => "v=spf1 include:_spf.gather.coop ~all",
        "spf_lookup_terms" => [{"term" => "include:_spf.gather.coop", "via" => nil}],
        "smtp2go_status" => "verified",
        "validation_records" => [
          {"kind" => "dkim", "host" => "s1._domainkey.#{domain.name}",
           "target" => "dkim.smtp2go.net", "actual" => "dkim.smtp2go.net",
           "verified" => true, "in_dns" => true}
        ]
      }
    end
  end
end
