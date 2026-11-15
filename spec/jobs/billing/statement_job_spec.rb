# frozen_string_literal: true

require "rails_helper"

describe Billing::StatementJob do
  include_context "jobs"

  describe "perform" do
    context "with accounts having activity" do
      # Accounts and households will be in Defaults.community
      let!(:trans1) { create(:transaction) }
      let!(:trans2) { create(:transaction) }
      subject(:job) { described_class.new(trans1.community_id) }

      it "should send emails and create statements" do
        expect(email_sent_by { perform_job }.size).to eq(2)
        expect(statement_count).to eq(2)

        # Should do nothing the second time because of recent statement.
        expect(email_sent_by { perform_job }.size).to eq(0)
        expect(statement_count).to eq(2)
      end
    end

    context "with a household whose members read email in different languages" do
      let!(:trans1) { create(:transaction) }
      let(:household) { trans1.account.household }
      subject(:job) { described_class.new(trans1.community_id) }

      before do
        create(:feature_flag, name: "i18n", status: true)
        household.users.first.update!(locale: "de")
        create(:user, household: household, locale: "fr")
      end

      it "sends each member their own statement notice, in their language" do
        emails = email_sent_by { perform_job }
        expect(emails.map(&:subject)).to contain_exactly(
          "Neuer Kontoauszug für #{trans1.community.name}",
          "Nouveau relevé de compte pour #{trans1.community.name}"
        )
        expect(statement_count).to eq(1)
      end
    end

    context "when the mail server rejects one member's address" do
      let!(:trans1) { create(:transaction) }
      let(:household) { trans1.account.household }
      let!(:other_member) { create(:user, household: household) }
      let(:bad_email) { household.users.detect { |u| u != other_member }.email }
      subject(:job) { described_class.new(trans1.community_id) }

      before do
        allow_any_instance_of(Mail::Message).to receive(:deliver).and_wrap_original do |original, *args|
          if original.receiver.to.include?(bad_email)
            raise Net::SMTPFatalError, "550 5.1.1 Recipient address rejected"
          end
          original.call(*args)
        end
      end

      it "still sends the notice to the others and reports the rejection" do
        expect(Gather::ErrorReporter.instance).to receive(:report).with(Net::SMTPFatalError, anything).once
        emails = email_sent_by { perform_job }
        expect(emails.map(&:to)).to eq([[other_member.email]])
        expect(statement_count).to eq(1)
      end
    end

    context "with no accounts having activity" do
      subject(:job) { described_class.new(Defaults.community.id) }

      it "should do nothing" do
        expect(email_sent_by { perform_job }.size).to eq(0)
        expect(statement_count).to eq(0)
      end
    end

    def statement_count
      ActsAsTenant.without_tenant { Billing::Statement.count }
    end
  end
end
