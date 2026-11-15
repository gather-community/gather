# frozen_string_literal: true

# Stored mail DNS/SMTP2GO check results for domains, shown on the admin domains dashboard.
module DomainMail
  def self.table_name_prefix
    "domain_mail_"
  end
end
