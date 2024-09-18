# frozen_string_literal: true

require "rails_helper"

describe AccountMailer do
  # Make separate community in cluster to test cross-community billing
  let(:community) { create(:community) }

  let(:users) { create_list(:user, 2) }
  let(:household) { create(:household, users: users) }
  let(:account) { create(:account, household: household, community: community) }
  let(:statement) { create(:statement, account: account, total_due: 9.99) }
  let!(:billers) { create_list(:biller, 2, community: community) }
  let!(:inactive_biller) { create(:biller, :inactive, community: community) }

  shared_examples_for "statement email" do
    context "with active users" do
      it "sets the right recipients" do
        expect(mail.to).to match_array(users.map(&:email))
      end

      it "sets the right reply to" do
        expect(mail.reply_to).to match_array(billers.map(&:email))
      end

      it "renders the correct name and URL in the body" do
        expect(mail.body.encoded).to match("Dear #{household.name} Household,")
        expect(mail.body.encoded).to include("The amount due is $9.99.")
        expect(mail.body.encoded).to contain_community_url(statement.community, "/statements/#{statement.id}")
      end
    end

    context "with all inactive users" do
      before do
        users[0].deactivate
        users[1].deactivate
      end

      it "sends to same recipients anyway unlike most emails" do
        expect(mail.to).to match_array(users.map(&:email))
      end
    end
  end

  describe "statement_notice" do
    let(:mail) { described_class.statement_notice(statement).deliver_now }

    context "with billers" do
      it_behaves_like "statement email"

      it "renders the subject" do
        expect(mail.subject).to eq("New Account Statement for #{community.name}")
      end
    end

    context "with no billers" do
      let(:billers) { [] }

      it "sets the right reply to" do
        expect(mail.reply_to).to be_empty
      end
    end
  end

  describe "statement_reminder" do
    let(:mail) { described_class.statement_reminder(statement).deliver_now }

    it_behaves_like "statement email"

    it "renders the subject" do
      expect(mail.subject).to eq("Payment Reminder for #{community.name} Account")
    end
  end
end
