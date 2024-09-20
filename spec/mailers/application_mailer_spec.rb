# frozen_string_literal: true

require "rails_helper"

describe ApplicationMailer do
  # Sample mailers for testing only.
  class SampleMailer < ApplicationMailer
    def sample(recipients)
      @community = recipients.first.community
      mail(to: recipients, subject: "Test", body: "Test")
    end
  end

  class SampleInactiveIfNoActiveMailer < ApplicationMailer
    def sample(recipients)
      @community = recipients.first.community
      mail(to: recipients, subject: "Test", body: "Test", include_inactive: :if_no_active)
    end
  end

  class SampleInactiveAlwaysMailer < ApplicationMailer
    def sample(recipients)
      @community = recipients.first.community
      mail(to: recipients, subject: "Test", body: "Test", include_inactive: :always)
    end
  end

  describe "recipient resolution" do
    context "with fake users" do
      let(:fake1) { create(:user, fake: true) }
      let(:fake2) { create(:user, fake: true) }
      let(:real1) { create(:user) }
      let(:real2) { create(:user) }
      let(:household) { create(:household, users: [fake2, real2]) }
      let(:mail) { SampleMailer.sample([fake1, real1, household]).deliver_now }

      it "sets the right recipients" do
        expect(mail.to).to match_array([real1, real2].map(&:email))
      end
    end

    context "with unconfirmed and inactive adults" do
      let(:unconfirmed1) { create(:user, :unconfirmed) }
      let(:unconfirmed2) { create(:user, :unconfirmed) }
      let(:inactive) { create(:user, :inactive) }
      let(:confirmed1) { create(:user) }
      let(:confirmed2) { create(:user) }
      let(:unconfirmed_child) { create(:user, :child) }
      let(:household) { create(:household, users: [unconfirmed2, confirmed2, inactive]) }
      let(:mail) { SampleMailer.sample([unconfirmed1, confirmed1, household, unconfirmed_child]).deliver_now }

      it "sets the right recipients" do
        expect(mail.to).to match_array([confirmed1, confirmed2, unconfirmed_child].map(&:email))
      end
    end

    context "with children with own emails" do
      let(:adult1) { create(:user) }
      let(:child1) { create(:user, :child, guardians: [adult1]) }
      let(:adult2) { create(:user) }
      let(:child2) { create(:user, :child, guardians: [adult2]) }
      let(:household) { create(:household, users: [adult2, child2]) }
      let(:mail) { SampleMailer.sample([child1, household]).deliver_now }

      it "sets the right recipients" do
        expect(mail.to).to match_array([child1, adult2, child2].map(&:email))
      end
    end

    context "with children without own emails" do
      let(:adult1) { create(:user) }
      let(:child1) { create(:user, :child, email: nil, guardians: [adult1]) }
      let(:adult2) { create(:user) }
      let(:adult3) { create(:user) }
      let(:adult4) { create(:user) }
      let(:child2) { create(:user, :child, email: nil, guardians: [adult2, adult4]) }
      let(:household) { create(:household, users: [adult2, adult3, child2]) }
      let(:mail) { SampleMailer.sample([child1, household]).deliver_now }

      it "maps to parents' emails only when mentioned directly, not via household" do
        expect(mail.to).to match_array([adult1, adult2, adult3].map(&:email))
      end
    end

    context "with include_inactive flag" do
      context "with all inactive users" do
        let(:adult1) { create(:user, :inactive) }
        let(:adult2) { create(:user, :inactive) }
        let(:household) { create(:household, users: [adult1, adult2]) }
        let(:mail1) { SampleInactiveIfNoActiveMailer.sample([household]).deliver_now }
        let(:mail2) { SampleInactiveAlwaysMailer.sample([household]).deliver_now }

        before { household.reload }

        it "includes inactive users for both include_inactive settings" do
          expect(mail1.to).to match_array([adult1, adult2].map(&:email))
          expect(mail2.to).to match_array([adult1, adult2].map(&:email))
        end
      end

      context "with at least one active household member" do
        let(:adult1) { create(:user) }
        let(:adult2) { create(:user, :inactive) }
        let(:household) { create(:household, users: [adult1, adult2]) }
        let(:mail1) { SampleInactiveIfNoActiveMailer.sample([household]).deliver_now }
        let(:mail2) { SampleInactiveAlwaysMailer.sample([household]).deliver_now }

        before { household.reload }

        it "does not include inactive users for :if_no_active but does for :always" do
          expect(mail1.to).to match_array([adult1].map(&:email))
          expect(mail2.to).to match_array([adult1, adult2].map(&:email))
        end
      end
    end
  end
end
