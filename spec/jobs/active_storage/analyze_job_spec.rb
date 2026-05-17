# frozen_string_literal: true

require "rails_helper"

describe ActiveStorage::AnalyzeJob do
  let(:user) { create(:user, :with_photo) }

  it "succeeds when no tenant is set, as in a Delayed Job worker" do
    blob = user.photo.blob  # evaluate while tenant context is active

    # Simulate Delayed Job: no tenant set, require_tenant still enforced
    ActsAsTenant.current_tenant = nil

    expect { described_class.perform_now(blob) }.not_to raise_error
  end
end
