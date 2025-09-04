# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  name       :string           not null
#  updated_at :datetime         not null
#
require "rails_helper"

describe Domain do
  describe "factory" do
    it "is valid" do
      expect(create(:domain).communities.size).to eq(1)
    end
  end

  describe "validations" do
    describe "name" do
      it "must match domain regex pattern" do
        valid_domains = [
          "example.com",
          "sub.example.com",
          "test-domain.com",
          "domain123.com",
          "a.b.c.d.com"
        ]

        valid_domains.each do |domain_name|
          domain = build(:domain, name: domain_name)
          expect(domain).to be_valid, "Expected #{domain_name} to be valid"
        end
      end

      it "rejects invalid domain formats" do
        invalid_domains = [
          "example",
          ".example.com",
          "example.",
          "example..com",
          "example-.com",
          "-example.com",
          "example.com-",
          "example@.com",
          "example com"
        ]

        invalid_domains.each do |domain_name|
          domain = build(:domain, name: domain_name)
          expect(domain).not_to be_valid, "Expected #{domain_name} to be invalid"
          expect(domain.errors[:name]).to be_present
        end
      end
    end

    describe "name uniqueness" do
      let!(:existing_domain) { create(:domain, name: "test.com") }
      let(:new_domain) { build(:domain, name: "test.com") }
      let!(:different_domain) { build(:domain, name: "test2.com") }

      it "enforces uniqueness across the system" do
        expect(new_domain).not_to be_valid
        expect(new_domain.errors[:name]).to include("has already been taken")
      end

      it "allows different names" do
        create(:domain, name: "test1.com")
        expect(different_domain).to be_valid
      end
    end

    describe "at least one ownership" do
      let(:domain_without_ownerships) { build(:domain) }
      let(:domain_with_ownerships) { create(:domain) }
      let(:domain_with_multiple_ownerships) { create(:domain) }
      let(:additional_community) { create(:community) }

      before do
        domain_without_ownerships.ownerships.clear
        # Add another ownership to domain_with_multiple_ownerships
        domain_with_multiple_ownerships.ownerships.build(community: additional_community)
        domain_with_multiple_ownerships.save!
      end

      it "requires at least one ownership" do
        expect(domain_without_ownerships).not_to be_valid
        expect(domain_without_ownerships.errors[:base]).to include("Please select at least one community")
      end

      it "is valid with ownerships" do
        expect(domain_with_ownerships).to be_valid
      end

      it "is valid when ownerships are marked for destruction but others remain" do
        # Mark one for destruction
        domain_with_multiple_ownerships.ownerships.first.mark_for_destruction
        expect(domain_with_multiple_ownerships).to be_valid
      end
    end
  end

  describe "scopes" do
    let(:community1) { create(:community) }
    let(:community2) { create(:community) }
    let(:community3) { create(:community) }

    let(:domain1) { create(:domain, name: "a.example.com") }
    let(:domain2) { create(:domain, name: "b.example.com") }
    let(:domain3) { create(:domain, name: "c.example.com") }

    before do
      # Set up ownerships
      domain1.communities = [community1]
      domain2.communities = [community1, community2]
      domain3.communities = [community2, community3]
    end

    describe ".in_community" do
      it "finds domains in a specific community" do
        result = Domain.in_community(community1)
        expect(result).to include(domain1, domain2)
        expect(result).not_to include(domain3)
      end
    end

    describe ".in_communities" do
      it "finds domains in all specified communities" do
        result = Domain.in_communities([community1, community2])
        expect(result).to include(domain2)
        expect(result).not_to include(domain1, domain3)
      end

      it "works with single community" do
        result = Domain.in_communities([community1])
        expect(result).to include(domain1, domain2)
      end
    end

    describe ".by_name" do
      it "orders domains alphabetically by name" do
        # Create domains in non-alphabetical order
        domain3
        domain1
        domain2

        result = Domain.by_name
        p result.map(&:name)
        expect(result.to_a).to eq([domain1, domain2, domain3])
      end
    end
  end

  describe "destruction" do
    context "with ownership and mailman list" do
      let!(:domain) { create(:domain) }
      let!(:ownership) { domain.ownerships[0] }
      let!(:list) { create(:group_mailman_list, domain: domain) }

      it "cascades" do
        domain.destroy
        expect { list.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { ownership.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
