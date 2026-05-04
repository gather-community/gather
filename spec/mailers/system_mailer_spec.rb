# frozen_string_literal: true

require "rails_helper"

describe SystemMailer do
  let(:community) { Defaults.community }

  describe "deletion_ready_notice" do
    subject(:mail) { described_class.deletion_ready_notice([community]).deliver_now }

    it "sends to support@gather.coop" do
      expect(mail.to).to eq(["support@gather.coop"])
    end

    it "includes the community name and slug in the subject" do
      expect(mail.subject).to include("1 community ready for deletion")
    end

    it "includes the community details in the body" do
      expect(mail.body.encoded).to include(community.name)
      expect(mail.body.encoded).to include(community.slug)
      expect(mail.body.encoded).to include(community.id.to_s)
    end

    it "includes a console snippet with CommunityDeletionJob" do
      expect(mail.body.encoded).to include("CommunityDeletionJob.perform_later")
      expect(mail.body.encoded).to include("actor_id = YOUR_SUPER_ADMIN_USER_ID")
      expect(mail.body.encoded).to include(community.id.to_s)
    end

    it "mentions the weekly repeat" do
      expect(mail.body.encoded).to include("repeat weekly")
    end
  end

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
