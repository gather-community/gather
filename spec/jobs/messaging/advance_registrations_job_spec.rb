# frozen_string_literal: true

require "rails_helper"

describe Messaging::AdvanceRegistrationsJob do
  include_context "jobs"

  it "enqueues a step for each registration waiting on Telnyx, and none for the rest" do
    waiting = [
      create(:messaging_registration, status: "brand_pending", community: create(:community)),
      create(:messaging_registration, status: "campaign_pending", community: create(:community)),
      create(:messaging_registration, status: "awaiting_payment", paid_at: Time.current,
        community: create(:community))
    ]
    create(:messaging_registration, status: "awaiting_payment", community: create(:community)) # unpaid
    create(:messaging_registration, status: "draft", community: create(:community))
    create(:messaging_registration, status: "approved", community: create(:community))

    expect { perform_job }.to have_enqueued_job(Messaging::AdvanceRegistrationJob).exactly(3).times
    waiting.each { |r| expect(Messaging::AdvanceRegistrationJob).to have_been_enqueued.with(r.id) }
  end
end

describe Messaging::AdvanceRegistrationJob do
  include_context "jobs"

  let(:registration) { create(:messaging_registration, status: "brand_pending") }
  subject(:job) { described_class.new(registration.id) }

  it "advances the registration with the submitter, inside its cluster" do
    submitter = instance_double(Messaging::RegistrationSubmitter)
    expect(Messaging::RegistrationSubmitter).to receive(:new).with(registration).and_return(submitter)
    expect(submitter).to receive(:advance) { expect(ActsAsTenant.current_tenant).to eq(registration.cluster) }
    perform_job
  end
end
