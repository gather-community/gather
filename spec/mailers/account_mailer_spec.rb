require "rails_helper"

describe AccountMailer do
  let(:users) { create_list(:user, 2) }
  let(:household) { create(:household, users: users) }
  let(:account) { create(:account, household: household, community: community) }
  let(:statement) { create(:statement, account: account, total_due: 9.99) }

  # Make separate community in cluster to test cross-community billing
  let(:community) { create(:community) }

  describe "statement_notice" do
    let(:mail) { described_class.statement_notice(statement).deliver_now }

    it "sets the right recipients" do
      expect(mail.to).to match_array(users.map(&:email))
    end

    it "renders the subject" do
      expect(mail.subject).to eq("New Account Statement for #{community.name}")
    end

    it "renders the correct name and URL in the body" do
      expect(mail.body.encoded).to match("Dear #{household.name} Household,")
      expect(mail.body.encoded).to include("The amount due is $9.99.")
      expect(mail.body.encoded).to have_correct_statement_url(statement)
    end
  end

  describe "statement_reminder" do
    let(:mail) { described_class.statement_reminder(statement).deliver_now }

    it "sets the right recipients" do
      expect(mail.to).to match_array(users.map(&:email))
    end

    it "renders the subject" do
      expect(mail.subject).to eq("Payment Reminder for #{community.name} Account")
    end

    it "renders the correct name and URL in the body" do
      expect(mail.body.encoded).to match("Dear #{household.name} Household,")
      expect(mail.body.encoded).to include("The amount due is $9.99.")
      expect(mail.body.encoded).to have_correct_statement_url(statement)
    end
  end

  def have_correct_statement_url(statement)
    contain_community_url(statement.community, "/statements/#{statement.id}")
  end
end
