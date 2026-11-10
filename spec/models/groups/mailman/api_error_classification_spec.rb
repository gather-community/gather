# frozen_string_literal: true

require "rails_helper"

# Sync jobs retry Api::ServerError, so only 5xx responses should raise it.
describe Groups::Mailman::Api do
  include WebMock::API

  after { WebMock.reset! }

  let(:mm_user) { Groups::Mailman::User.new(remote_id: "abcd") }
  let(:url) { "#{Settings.mailman.api.base_url}/3.1/users/abcd" }

  before do
    stub_request(:delete, url).to_return(status: status, body: "")
  end

  context "with a 502 from the server" do
    let(:status) { 502 }

    it "raises a ServerError" do
      expect { described_class.instance.delete_user(mm_user) }.to raise_error(described_class::ServerError)
    end
  end

  context "with a 400" do
    let(:status) { 400 }

    it "raises a plain ApiRequestError" do
      expect { described_class.instance.delete_user(mm_user) }.to raise_error(ApiRequestError) do |error|
        expect(error).not_to be_a(described_class::ServerError)
      end
    end
  end

  context "with a 404" do
    let(:status) { 404 }

    it "still counts as already deleted" do
      expect { described_class.instance.delete_user(mm_user) }.not_to raise_error
    end
  end
end
