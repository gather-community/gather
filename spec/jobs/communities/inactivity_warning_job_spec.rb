# frozen_string_literal: true

require "rails_helper"

describe Communities::InactivityWarningJob do
  include_context "jobs"

  let!(:community) { Defaults.community }

  # Mail stub shared across tests - can be overridden per context
  let(:mail_dbl) { double(deliver_now: nil) }

  before do
    allow(Communities::InactivityMailer).to receive(:warning).and_return(mail_dbl)
    allow(SystemMailer).to receive(:inactivity_warning_summary).and_return(mail_dbl)
    allow(SystemMailer).to receive(:deletion_ready_notice).and_return(mail_dbl)
    # Default: no subscription
    allow(community).to receive(:subscription).and_return(nil)
  end

  def make_inactive(days_ago: 100)
    create(:user, community: community).tap do |u|
      u.update_column(:last_sign_in_at, days_ago.days.ago)
    end
  end

  def make_admin(community)
    create(:user, community: community).tap do |u|
      u.add_role(:admin, community)
    end
  end

  context "with a community inactive for > 90 days" do
    before { make_inactive }

    context "with no previous warnings (count=0)" do
      it "sends warning 1 and updates warning state" do
        perform_job
        expect(Communities::InactivityMailer).to have_received(:warning)
          .with(community, 1, anything, anything)
        community.reload
        expect(community.inactivity_warning_count).to eq(1)
        expect(community.inactivity_warning_sent_at).to be_within(5.seconds).of(Time.current)
      end
    end

    context "with warning count=1 and sent 8 days ago" do
      before do
        community.update!(inactivity_warning_count: 1,
          inactivity_warning_sent_at: 8.days.ago)
      end

      it "sends warning 2" do
        perform_job
        expect(Communities::InactivityMailer).to have_received(:warning)
          .with(community, 2, anything, anything)
        expect(community.reload.inactivity_warning_count).to eq(2)
      end

      it "does not send the summary email" do
        perform_job
        expect(SystemMailer).not_to have_received(:inactivity_warning_summary)
      end
    end

    context "with warning count=2 and sent 8 days ago" do
      before do
        community.update!(inactivity_warning_count: 2,
          inactivity_warning_sent_at: 8.days.ago)
      end

      it "sends warning 3 (final)" do
        perform_job
        expect(Communities::InactivityMailer).to have_received(:warning)
          .with(community, 3, anything, anything)
        expect(community.reload.inactivity_warning_count).to eq(3)
      end

      it "sends summary email to support after warning 3" do
        perform_job
        expect(SystemMailer).to have_received(:inactivity_warning_summary)
          .with([community])
      end
    end

    context "with warning count=3 and sent 8 days ago" do
      before do
        community.update!(inactivity_warning_count: 3,
          inactivity_warning_sent_at: 8.days.ago)
      end

      it "archives the community" do
        perform_job
        expect(community.reload.archived_at).to be_within(5.seconds).of(Time.current)
      end

      it "sends a deletion ready notice to support" do
        perform_job
        expect(SystemMailer).to have_received(:deletion_ready_notice).with([community])
      end

      it "updates inactivity_warning_sent_at so the notice repeats weekly" do
        perform_job
        expect(community.reload.inactivity_warning_sent_at).to be_within(5.seconds).of(Time.current)
      end

      it "does not send a warning email" do
        perform_job
        expect(Communities::InactivityMailer).not_to have_received(:warning)
      end
    end

    context "with warning count=1 but sent only 3 days ago" do
      before do
        community.update!(inactivity_warning_count: 1,
          inactivity_warning_sent_at: 3.days.ago)
      end

      it "does not send another warning yet" do
        perform_job
        expect(Communities::InactivityMailer).not_to have_received(:warning)
        expect(community.reload.inactivity_warning_count).to eq(1)
      end
    end
  end

  context "when the community is already archived" do
    before do
      community.update!(archived_at: 30.days.ago, inactivity_warning_count: 3,
        inactivity_warning_sent_at: 8.days.ago)
    end

    it "sends another deletion ready notice" do
      perform_job
      expect(SystemMailer).to have_received(:deletion_ready_notice).with([community])
    end

    it "bumps inactivity_warning_sent_at" do
      perform_job
      expect(community.reload.inactivity_warning_sent_at).to be_within(5.seconds).of(Time.current)
    end

    it "does not send a warning email" do
      perform_job
      expect(Communities::InactivityMailer).not_to have_received(:warning)
    end

    context "when the re-notification interval has not elapsed" do
      before { community.update!(inactivity_warning_sent_at: 3.days.ago) }

      it "does not send a notice" do
        perform_job
        expect(SystemMailer).not_to have_received(:deletion_ready_notice)
      end
    end
  end

  context "when the community logs in after a warning" do
    before do
      make_inactive
      community.update!(inactivity_warning_count: 1,
        inactivity_warning_sent_at: 10.days.ago)
      # Simulate a login after the warning was sent
      create(:user, community: community).tap do |u|
        u.update_column(:last_sign_in_at, 5.days.ago)
      end
    end

    it "resets warning state and does not send email" do
      perform_job
      expect(Communities::InactivityMailer).not_to have_received(:warning)
      community.reload
      expect(community.inactivity_warning_count).to eq(0)
      expect(community.inactivity_warning_sent_at).to be_nil
    end
  end

  context "when the community is active (logged in within 90 days)" do
    before { make_inactive(days_ago: 30) }

    it "does not send a warning" do
      perform_job
      expect(Communities::InactivityMailer).not_to have_received(:warning)
      expect(community.reload.inactivity_warning_count).to eq(0)
    end
  end

  context "when the community has a protected slug" do
    before do
      make_inactive
      community.update_column(:slug, "demo")
    end

    after { community.update_column(:slug, "default") }

    it "does not send a warning" do
      perform_job
      expect(Communities::InactivityMailer).not_to have_received(:warning)
    end
  end

  context "when the community has an active Stripe subscription" do
    before do
      make_inactive
      create(:subscription, community: community)
      allow_any_instance_of(Subscription::Subscription).to receive(:populate)
      allow_any_instance_of(Subscription::Subscription).to receive(:active?).and_return(true)
    end

    it "does not send a warning" do
      perform_job
      expect(Communities::InactivityMailer).not_to have_received(:warning)
    end
  end

  context "when the Stripe API call fails" do
    before do
      make_inactive
      create(:subscription, community: community)
      allow_any_instance_of(Subscription::Subscription).to receive(:populate)
        .and_raise(Stripe::StripeError.new("connection error"))
      allow(Rails.logger).to receive(:error)
    end

    it "skips the community and logs the error" do
      perform_job
      expect(Communities::InactivityMailer).not_to have_received(:warning)
      expect(Rails.logger).to have_received(:error).with(/Stripe error.*#{community.name}/)
    end
  end

  context "when the community has no active admins" do
    before do
      make_inactive
      # No admin role assigned — fallback to support@ is handled in mailer
    end

    it "calls the mailer with an empty admins list" do
      admins_arg = nil
      allow(Communities::InactivityMailer).to receive(:warning) do |_cmty, _count, _login, admins|
        admins_arg = admins
        mail_dbl
      end
      perform_job
      expect(admins_arg).to be_empty
    end
  end

  context "when the community has an admin" do
    let!(:admin) { make_admin(community) }
    before { make_inactive }

    it "calls the mailer with the admin" do
      admins_arg = nil
      allow(Communities::InactivityMailer).to receive(:warning) do |_cmty, _count, _login, admins|
        admins_arg = admins
        mail_dbl
      end
      perform_job
      expect(admins_arg).to include(admin)
    end
  end
end
