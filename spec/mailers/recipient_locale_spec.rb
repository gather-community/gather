# frozen_string_literal: true

require "rails_helper"

describe RecipientLocale do
  include ActiveJob::TestHelper

  it "is included in every mailer" do
    Rails.application.eager_load!
    app_dir = Rails.root.join("app").to_s
    mailers = ActionMailer::Base.descendants.select do |klass|
      klass.name && Object.const_source_location(klass.name)&.first&.start_with?(app_dir)
    end
    expect(mailers).to include(ApplicationMailer, AuthMailer)
    missing = mailers.reject { |mailer| mailer.include?(described_class) }
    expect(missing).to be_empty, "#{missing.map(&:name).join(", ")} must include RecipientLocale"
  end

  describe "delivery" do
    let(:user) { create(:user) }

    before do
      I18n.backend.store_translations(:fr,
        auth_mailer: {sign_in_invitation: {subject: "Instructions en français"}})
    end

    after do
      I18n.reload!
    end

    # ActiveJob restores the locale that was active at enqueue time, i.e. the sender's browser language.
    it "renders in the recipient's locale, not the one it was enqueued under" do
      I18n.with_locale(:fr) { AuthMailer.sign_in_invitation(user, "xyz").deliver_later }
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob)
      expect(ActionMailer::Base.deliveries.last.subject).to eq("Instructions for Signing in to Gather")
    end
  end

  describe "the recipient's language" do
    let(:community) { Defaults.community }
    let(:german) { create(:user, locale: "de") }
    let(:swedish) { create(:user, locale: "sv") }
    let(:no_preference) { create(:user, locale: nil) }

    def warning_subject(admins)
      Communities::InactivityMailer.with(recipient: admins).warning(community, 1, nil, admins).subject
    end

    context "with the i18n feature flag on" do
      before do
        create(:feature_flag, name: "i18n", status: true)
        community.settings.locale = "sv"
        community.save!
      end

      it "renders mail sent with .with(recipient:) in the recipient's chosen language" do
        expect(warning_subject([german])).to eq("Warnung wegen Inaktivität für #{community.name}")
      end

      it "falls back to the community's default for recipients who haven't chosen" do
        expect(warning_subject([no_preference])).to eq("Varning för inaktivitet i #{community.name}")
      end

      it "renders a group sharing a language in that language" do
        expect(warning_subject([no_preference, swedish])).to eq("Varning för inaktivitet i #{community.name}")
      end

      it "uses the default locale for a group that doesn't share one" do
        expect(warning_subject([german, swedish])).to eq("Inactivity warning for #{community.name}")
      end

      it "renders mailers whose recipient is an argument in that user's language" do
        mail_subject = AuthMailer.sign_in_invitation(german, "xyz").subject
        expect(mail_subject).to eq("Anleitung zur Anmeldung bei Gather")
      end
    end

    context "with the i18n feature flag off" do
      it "renders in the default locale whatever the recipient chose" do
        expect(warning_subject([german])).to eq("Inactivity warning for #{community.name}")
        mail_subject = AuthMailer.sign_in_invitation(german, "xyz").subject
        expect(mail_subject).to eq("Instructions for Signing in to Gather")
      end
    end
  end
end
