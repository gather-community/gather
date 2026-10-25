# frozen_string_literal: true

require "rails_helper"

describe SystemMailer do
  let(:community) { Defaults.community }

  describe "inactivity_warning_summary" do
    before { community.update!(inactivity_warning_count: 3, inactivity_warning_sent_at: Time.current) }

    subject(:mail) { described_class.inactivity_warning_summary([community]).deliver_now }

    it "sends to support@gather.coop" do
      expect(mail.to).to eq(["support@gather.coop"])
    end

    it "includes the community name" do
      expect(mail.body.encoded).to include(community.name)
    end
  end
end
