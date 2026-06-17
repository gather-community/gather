# frozen_string_literal: true

require "rails_helper"

describe Billing::TransactionSearchSerializer do
  let(:community) { Defaults.community }
  let(:household) { create(:household, community: community) }
  let(:account) { household.accounts[0] }
  let(:transaction) { create(:transaction, account: account, description: "Monthly dues", code: "dues") }

  subject(:data) { described_class.new(transaction).as_json }

  it "serializes without error and includes required fields" do
    expect(data).to include(
      id: transaction.id,
      kind: "transaction",
      community_id: community.id,
      account_id: account.id,
      description: "Monthly dues",
      code: "dues"
    )
  end
end
