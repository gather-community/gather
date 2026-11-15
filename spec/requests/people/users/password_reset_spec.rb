# frozen_string_literal: true

require "rails_helper"

# Password reset is on the apex domain, where no tenant is set. The email to someone who can't
# reset their password goes through a job that has to load the user when it runs.
describe "password reset for a user without full access" do
  include ActiveJob::TestHelper

  let!(:user) { create(:user, :child) }

  # Jobs left in the test queue by earlier specs would run too.
  before { clear_enqueued_jobs }

  it "sends the email saying they can't reset it" do
    host!(Settings.url.host)
    post("/people/users/password", params: {user: {email: user.email}})

    # Run the job as a worker would, with no tenant and scoping still on.
    ActsAsTenant.current_tenant = nil
    emails = email_sent_by { perform_enqueued_jobs }
    expect(emails.map(&:to)).to eq([[user.email]])
    expect(emails[0].body.encoded).to match("your profile does not have full system access")
  end
end
