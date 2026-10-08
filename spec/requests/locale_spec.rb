# frozen_string_literal: true

require "rails_helper"

# Resolution rules are covered in spec/lib/gather/locales_spec.rb. These check the controller wiring.
describe "request locale" do
  let(:french) { {"Accept-Language" => "fr-CA,fr;q=0.9,en;q=0.8"} }
  let(:user) { create(:user, calendar_token: "z8-fwETMhx93t9nxkeQ_") }

  before do
    allow(I18n).to receive(:with_locale).and_call_original
  end

  it "serves released locales to signed-out visitors and varies by Accept-Language" do
    get("/", headers: french)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<html lang="en"')
    expect(response.headers["Vary"]).to include("Accept-Language")
  end

  context "when signed in" do
    before do
      use_user_subdomain(user)
      sign_in(user)
    end

    it "ignores unreleased locales without the feature flag" do
      get(users_path, headers: french)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<html lang="en"')
    end

    context "with the i18n feature flag" do
      before do
        create(:feature_flag, name: "i18n", interface: "user").users << user
      end

      # Pages can't render in French until it's translated (tests raise on missing translations), so this
      # runs the action in the current locale and only checks which locale was chosen.
      it "switches to the browser's locale" do
        expect(I18n).to receive(:with_locale).with(:"fr-CA") { |&block| block.call }
        get(users_path, headers: french)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context "with a calendar feed" do
    let!(:calendar) { create(:calendar, community: user.community) }

    before do
      use_user_subdomain(user)
      create(:feature_flag, name: "i18n", interface: "user").users << user
    end

    it "renders in the default locale regardless of the header" do
      expect(I18n).not_to receive(:with_locale).with(:"fr-CA")
      get("/calendars/export.ics?calendars=#{calendar.id}&token=#{user.calendar_token}", headers: french)
      expect(response).to have_http_status(:ok)
      expect(response.headers["Vary"].to_s).not_to include("Accept-Language")
    end
  end
end
