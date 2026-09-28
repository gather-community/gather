# frozen_string_literal: true

require "rails_helper"

describe "reporting of unauthorized requests" do
  let(:user) { create(:user) }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  def request_forbidden_page(referer)
    headers = referer ? {"Referer" => referer} : {}
    expect { get("/calendars", headers: headers) }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "reports a warning when the referrer is one of our pages" do
    expect(Gather::ErrorReporter.instance).to receive(:report) do |error, level:, data:|
      expect(error).to be_a(ApplicationControllable::RequestPreprocessing::InternalLinkDenied)
      expect(error.message).to match(/\ACalendars::\w+Policy#index\?\z/)
      expect(level).to eq(:warning)
      expect(data[:referrer]).to end_with("/meals")
    end
    request_forbidden_page("http://#{user.subdomain}.#{Settings.url.host}/meals")
  end

  it "doesn't report when the referrer is external" do
    expect(Gather::ErrorReporter.instance).not_to receive(:report)
    request_forbidden_page("https://evil.#{Settings.url.host}.example.com/")
  end

  it "doesn't report when there is no referrer" do
    expect(Gather::ErrorReporter.instance).not_to receive(:report)
    request_forbidden_page(nil)
  end
end
