# frozen_string_literal: true

require "rails_helper"

describe "admin domains dashboard" do
  let!(:actor) { create(:super_admin) }
  let!(:migrated_domain) { create(:domain, name: "done.example.org") }
  let!(:pending_domain) { create(:domain, name: "notyet.example.org") }
  let!(:unchecked_domain) { create(:domain, name: "fresh.example.org") }
  let!(:gather_domain) { create(:domain, name: "#{Defaults.community.slug}.gather.coop") }
  let!(:other_cluster) { create(:cluster, name: "Other Cluster") }
  let!(:other_cluster_domain) do
    with_tenant(other_cluster) do
      community = create(:community, name: "Other Community")
      create(:domain, name: "othercluster.example.org", communities: [community])
    end
  end

  let!(:migrated_check) { create(:domain_mail_check, domain: migrated_domain) }
  let!(:pending_check) do
    create(:domain_mail_check, domain: pending_domain, data: {
      "mx" => [[10, "mail.oldhost.example"]],
      "spf" => nil,
      "smtp2go_status" => "pending",
      "validation_records" => [
        {"kind" => "dkim", "host" => "s2._domainkey.notyet.example.org",
         "target" => "dkim.smtp2go.net", "verified" => false, "in_dns" => false},
        {"kind" => "return_path", "host" => "em2.notyet.example.org",
         "target" => "return.smtp2go.net", "verified" => false, "in_dns" => true}
      ]
    })
  end
  let!(:other_cluster_check) do
    with_tenant(other_cluster) do
      create(:domain_mail_check, domain: other_cluster_domain,
        data: {"mx" => [], "spf" => nil, "smtp2go_status" => "not_added",
               "validation_records" => []})
    end
  end

  before do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "happy path" do
    visit(admin_domains_path)

    expect(page).to have_content("Domains")
    expect(page).to have_content("1 of 4 domains have all records correct.")

    # Gather-managed domains are not part of the migration.
    expect(page).not_to have_content(gather_domain.name)

    migrated_row = find("tr", text: "done.example.org")
    expect(migrated_row).to have_content("Correct", count: 2)
    expect(migrated_row).to have_content("DKIM")

    pending_row = find("tr", text: "notyet.example.org")
    expect(pending_row).to have_content("Incorrect", count: 2)
    expect(pending_row).to have_content("DKIM")
    expect(pending_row).to have_content("Return")
    # The return path record is in DNS but unverified, so it shows the waiting state.
    expect(pending_row).to have_css(".validation-record.text-warning", text: "Return")
    expect(pending_row).to have_css(".validation-record.text-danger", text: "DKIM")

    # A domain with no stored check yet.
    fresh_row = find("tr", text: "fresh.example.org")
    expect(fresh_row).to have_content("Never checked")

    # Domains from other clusters are included.
    other_row = find("tr", text: "othercluster.example.org")
    expect(other_row).to have_content("Other Community")
    expect(other_row).to have_content("Not Added")
  end

  scenario "refresh all" do
    visit(admin_domains_path)
    click_button("Refresh All")

    expect(page).to have_content("Checking 4 domains in the background. " \
      "This should take about 9 seconds.")
    jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
    expect(jobs.size).to eq(1)
    expect(jobs[0]["job_class"]).to eq("DomainMail::RefreshJob")
  end

  scenario "refresh one row runs synchronously" do
    checker = instance_double(DomainMail::Checker, run: nil, smtp2go_error: nil)
    expect(DomainMail::Checker).to receive(:new) do |domains:|
      expect(domains.map(&:name)).to eq(%w[fresh.example.org])
      checker
    end

    visit(admin_domains_path)
    find("tr", text: "fresh.example.org").find("button[title='Re-check this domain']").click

    expect(page).to have_content("Re-checked fresh.example.org.")
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
  end

  scenario "refresh one row when the SMTP2GO API fails" do
    checker = instance_double(DomainMail::Checker, run: nil, smtp2go_error: :request_failed)
    allow(DomainMail::Checker).to receive(:new).and_return(checker)

    visit(admin_domains_path)
    find("tr", text: "fresh.example.org").find("button[title='Re-check this domain']").click

    expect(page).to have_content("Re-checked fresh.example.org, but the SMTP2GO API request " \
      "failed, so validation status may be stale.")
  end

  scenario "SMTP2GO API key not configured" do
    allow(Settings).to receive(:smtp2go).and_return(double(api_key: nil))

    visit(admin_domains_path)

    expect(page).to have_content("The SMTP2GO API key is not configured")
    expect(page).to have_content("done.example.org")
  end
end
