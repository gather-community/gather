# frozen_string_literal: true

require "rails_helper"

describe "mail migration page" do
  let!(:actor) { create(:super_admin) }
  let!(:migrated_domain) { create(:domain, name: "done.example.org") }
  let!(:unmigrated_domain) { create(:domain, name: "notyet.example.org") }
  let!(:gather_domain) { create(:domain, name: "#{Defaults.community.slug}.gather.coop") }
  let!(:other_cluster) { create(:cluster, name: "Other Cluster") }
  let!(:other_cluster_domain) do
    with_tenant(other_cluster) do
      community = create(:community, name: "Other Community")
      create(:domain, name: "othercluster.example.org", communities: [community])
    end
  end

  let(:good_mx) { MailMigration::DomainStatus::EXPECTED_MX }
  let(:client) { instance_double(Smtp2go::Client, configured?: true) }
  let(:dns_checker) { instance_double(MailMigration::DnsChecker) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
    allow(Smtp2go::Client).to receive(:new).and_return(client)
    allow(MailMigration::DnsChecker).to receive(:new).and_return(dns_checker)
  end

  def sender_domain(name, verified:)
    Smtp2go::SenderDomain.new(name: name, records: [
      Smtp2go::SenderDomain::DnsRecord.new(kind: :dkim, host: "s1._domainkey.#{name}",
        target: "dkim.smtp2go.net", verified: verified),
      Smtp2go::SenderDomain::DnsRecord.new(kind: :return_path, host: "em1.#{name}",
        target: "return.smtp2go.net", verified: verified)
    ])
  end

  scenario "happy path" do
    allow(client).to receive(:sender_domains).and_return([
      sender_domain("done.example.org", verified: true),
      sender_domain("notyet.example.org", verified: false)
    ])
    allow(dns_checker).to receive(:mx_records) do |name|
      (name == "done.example.org") ? good_mx : [[10, "mail.oldhost.example"]]
    end
    allow(dns_checker).to receive(:spf_record) do |name|
      (name == "done.example.org") ? "v=spf1 include:_spf.gather.coop ~all" : nil
    end
    allow(dns_checker).to receive(:cname_target) do |host|
      host.start_with?("s1._domainkey.") ? "dkim.smtp2go.net" : nil
    end

    visit(mail_migration_path)

    expect(page).to have_content("Mail Domain Migration")
    expect(page).to have_content("1 of 3 domains fully migrated.")

    # Gather-managed domains are not part of the migration.
    expect(page).not_to have_content(gather_domain.name)

    migrated_row = find("tr", text: "done.example.org")
    expect(migrated_row).to have_content("SMTP2GO")
    expect(migrated_row).to have_content("Updated", count: 2)
    expect(migrated_row).to have_content("Verified")

    pending_row = find("tr", text: "notyet.example.org")
    expect(pending_row).to have_content("Previous Host")
    expect(pending_row).to have_content("Not Updated", count: 2)
    expect(pending_row).to have_content("Pending")
    expect(pending_row).to have_content("DKIM")
    expect(pending_row).to have_content("Return Path")

    # Domains from other clusters are included.
    other_row = find("tr", text: "othercluster.example.org")
    expect(other_row).to have_content("Other Community")
    expect(other_row).to have_content("Not Added")
  end

  scenario "SMTP2GO API key not configured" do
    allow(client).to receive(:configured?).and_return(false)
    allow(dns_checker).to receive_messages(mx_records: [], spf_record: nil, cname_target: nil)

    visit(mail_migration_path)

    expect(page).to have_content("The SMTP2GO API key is not configured")
    expect(page).to have_content("done.example.org")
    expect(page).to have_content("Unknown")
  end
end
