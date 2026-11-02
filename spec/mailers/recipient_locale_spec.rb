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
end
