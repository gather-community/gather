# frozen_string_literal: true

require "rails_helper"

describe "gdrive auth" do
  let(:actor) { create(:admin) }

  before do
    sign_in(actor)
    create(:feature_flag, name: "gdrive", status: true)
  end

  describe "start" do
    before do
      use_user_subdomain(actor)
    end

    context "when saved credentials are present" do
      let!(:gdrive_config) { create(:gdrive_config) }

      it "redirects back to origin page" do
        VCR.use_cassette("gdrive/auth/start/with_creds") do
          get(gdrive_auth_start_path(origin: "/foo"))
          expect(response).to redirect_to("/foo")
        end
      end
    end
  end
end
