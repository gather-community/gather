# frozen_string_literal: true

require "rails_helper"

describe Communities::InactivityMailer do
  let(:community) { Defaults.community }
  let!(:admin) do
    create(:user, community: community).tap { |u| u.add_role(:admin, community) }
  end
  let(:last_login_at) { 100.days.ago }

  describe "warning" do
    context "warning 1 of 3 (not final)" do
      subject(:mail) do
        described_class.warning(community, 1, last_login_at,
          User.with_role(:admin, community).active).deliver_now
      end

      it "sends to the community admin" do
        expect(mail.to).to eq([admin.email])
      end

      it "uses the inactivity subject" do
        expect(mail.subject).to eq("Inactivity warning for #{community.name}")
      end

      it "mentions which warning number it is and includes the next-steps message" do
        expect(mail.body.encoded).to include("warning 1 of 3")
        expect(mail.body.encoded).to include("7 days")
        expect(mail.body.encoded).not_to include("Final")
      end

      it "includes the last login date" do
        expect(mail.body.encoded).to include(I18n.l(last_login_at.to_date))
      end
    end

    context "warning 3 of 3 (final)" do
      subject(:mail) do
        described_class.warning(community, 3, last_login_at,
          User.with_role(:admin, community).active).deliver_now
      end

      it "uses the final deletion subject" do
        expect(mail.subject).to eq("[Final Deletion Warning] #{community.name}")
      end

      it "includes the deletion warning message" do
        expect(mail.body.encoded).to include("warning 3 of 3")
        expect(mail.body.encoded).to include("deleted in approximately 7 days")
      end
    end

    context "when there are no community admins" do
      before { admin.remove_role(:admin, community) }

      subject(:mail) do
        described_class.warning(community, 1, last_login_at,
          User.with_role(:admin, community).active).deliver_now
      end

      it "falls back to support@gather.coop" do
        expect(mail.to).to eq(["support@gather.coop"])
      end
    end

    context "when the last login is nil (never logged in)" do
      subject(:mail) do
        described_class.warning(community, 1, nil, User.with_role(:admin, community).active).deliver_now
      end

      it "shows Never for the last login" do
        expect(mail.body.encoded).to include("Never")
      end
    end
  end
end
