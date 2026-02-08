# frozen_string_literal: true

require "rails_helper"

describe "user request" do
  let(:user) { create(:user) }
  let!(:mail_test_run) { create(:mail_test_run, mail_sent_at: Time.current - 1.minute) }

  shared_examples_for "works" do
    it do
      get("/ping") # This will be on apex domain since we didn't set a subdomain.
      expect(response).to have_http_status(200)
    end
  end

  context "when not signed in" do
    it_behaves_like "works"
  end

  context "when signed in" do
    before do
      sign_in(user)
    end

    it_behaves_like "works"
  end
end
