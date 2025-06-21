# frozen_string_literal: true

# == Schema Information
#
# Table name: billing_templates
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  code         :string(16)       not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  description  :string(255)      not null
#  updated_at   :datetime         not null
#  value        :decimal(10, 2)   not null
#
require "rails_helper"

describe Billing::Template do
  it "has a valid factory" do
    member_type = create(:member_type)
    create(:billing_template, member_types: [member_type])
  end

  describe "households" do
    let!(:memtype1) { create(:member_type) }
    let!(:memtype2) { create(:member_type) }
    let!(:household1) { create(:household, member_type: memtype1) }
    let!(:household2) { create(:household, member_type: memtype1) }
    let!(:household3) { create(:household, member_type: memtype2) }
    let!(:template1) { create(:billing_template, member_types: [memtype1, memtype2]) }
    let!(:template2) { create(:billing_template, member_types: [memtype2]) }

    it "is correct for template1" do
      expect(template1.households).to contain_exactly(household1, household2, household3)
    end

    it "is correct for template2" do
      expect(template2.households).to contain_exactly(household3)
    end
  end

  describe "apply" do
    let!(:household1) { create(:household) }
    let!(:household2) { create(:household) }
    let!(:household3) { create(:household) }
    let(:template) { create(:billing_template, description: "Foo", code: "othchg", value: 2.55) }

    before do
      allow(template).to receive(:households).and_return([household1, household2])
    end

    it "creates appropriate transactions" do
      template.apply
      expect(Billing::Transaction.count).to eq(2)

      [household1, household2].each do |household|
        txn = Billing::Transaction.find_by(account: Billing::Account.find_by(household: household))
        expect(txn.description).to eq("Foo")
        expect(txn.code).to eq("othchg")
        expect(txn.value).to be_within(0.0001).of(2.55)
        expect(txn.incurred_on).to eq(Time.zone.today)
        expect(txn.quantity).to be_nil
        expect(txn.unit_price).to be_nil
        expect(txn.statement_id).to be_nil
      end
    end
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  # - For fake users and households, destruction may happen when associations are present that would
  #   normally forbid it, but the deletion script can be ordered in such a way as to avoid problems by
  #   deleting dependent objects first, and then users and households.
  describe "destruction" do
    context "without associations" do
      let(:template) { create(:billing_template) }

      it "destroys cleanly" do
        template.destroy
      end
    end

    context "with member type" do
      let(:member_type) { create(:member_type) }
      let(:template) { create(:billing_template, member_types: [member_type]) }

      it "destroys cleanly but doesn't destroy member type" do
        template.destroy
        expect { member_type }.not_to raise_error
      end
    end
  end
end
