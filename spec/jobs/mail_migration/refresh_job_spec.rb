# frozen_string_literal: true

require "rails_helper"

describe MailMigration::RefreshJob do
  let!(:domain) { create(:domain, name: "one.example.org") }
  let!(:domain2) { create(:domain, name: "two.example.org") }
  let!(:gather_domain) { create(:domain, name: "#{Defaults.community.slug}.gather.coop") }
  let!(:other_cluster) { create(:cluster) }
  let!(:other_cluster_domain) do
    with_tenant(other_cluster) do
      community = create(:community)
      create(:domain, name: "three.example.org", communities: [community])
    end
  end
  let(:checker) { instance_double(MailMigration::Checker, run: nil) }

  it "checks all custom domains across clusters when no domain_id is given" do
    expect(MailMigration::Checker).to receive(:new) do |domains:|
      expect(domains.map(&:name)).to match_array(%w[one.example.org two.example.org three.example.org])
      checker
    end
    described_class.perform_now
  end

  it "checks only the given domain when domain_id is given" do
    expect(MailMigration::Checker).to receive(:new) do |domains:|
      expect(domains.map(&:name)).to eq(%w[two.example.org])
      checker
    end
    described_class.perform_now(domain_id: domain2.id)
  end
end
