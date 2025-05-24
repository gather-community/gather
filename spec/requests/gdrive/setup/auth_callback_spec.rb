# frozen_string_literal: true

require "rails_helper"

describe "gdrive auth callback" do
  include_context "gdrive"

  let(:actor) { create(:admin) }
  let(:redirect_url) { "http://default.gatherdev.org:31337/gdrive" }
  let(:callback_payload) do
    {
      "state" => "{\"community_id\":#{Defaults.community.id}," \
        "\"session_id\":\"P5JPu/n1QyYvkdEr3zgyHQ==\"," \
        "\"current_uri\":\"#{redirect_url}\"}",
      "code" => "4/0AX4XfWi1iHTsts9hiS2un1INqmi0KAIOB-iRL_OnUd7FCqyhJ7MDkPqmgjYlhAIoysAnpw",
      "scope" => "email profile https://www.googleapis.com/auth/drive openid " \
        "https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
      "authuser" => "1",
      "prompt" => "consent"
    }
  end

  before do
    sign_in(actor)
    create(:feature_flag, name: "gdrive", status: true)
  end

  context "when authenticated google ID matches stored config" do
    let!(:config) { create(:gdrive_config, org_user_id: "bar@gmail.com") }

    it "stores token and redirects" do
      # This token must match the `session_id` in the copied payload below.
      with_env("STUB_SESSION_G_XSRF_TOKEN" => "P5JPu/n1QyYvkdEr3zgyHQ==") do
        VCR.use_cassette("gdrive/setup/callback/success") do
          # The payload passed below mimics what is sent from Google in the OAuth callback.
          # The code is ephemeral so it is not a secret at this point.
          # This payload was obtained by:
          # 1. Adding a temporary `raise` call to the callback method
          # 2. Authenticating with Google in the development environment, triggering the raise call
          #    before the request out to Google to fetch an access token is made.
          # 3. Copying the payload from the development log.
          #
          # To get the test to pass and record the successful requests to Google, I had to manually
          # set `redirect_url` in the `authorizer` method in the controller to
          # use port 3000 and the https protocol, since that is what gets sent to Google in the authentication
          # flow in step 2 above. Once the cassette is recorded, the manual override of `redirect_url`
          # can be removed, and the port and protocol of the Gather URLs below and in the cassette
          # should be changed to 31337 and http respectively.
          get("/gdrive/setup/auth/callback", params: callback_payload)
          expect(response).to redirect_to(redirect_url)
          with_default_tenant do
            expect(GDrive::Token.count).to eq(1)
            token = GDrive::Token.first
            expect(token.google_user_id).to eq("bar@gmail.com")
          end
        end
      end
    end
  end

  context "when authenticated google ID does not match stored config" do
    let!(:config) { create(:gdrive_config, org_user_id: "foo@gmail.com") }

    it "redirects with error" do
      with_env("STUB_SESSION_G_XSRF_TOKEN" => "P5JPu/n1QyYvkdEr3zgyHQ==") do
        VCR.use_cassette("gdrive/setup/callback/success") do
          get("/gdrive/setup/auth/callback", params: callback_payload)
          expect(response).to redirect_to(redirect_url)
          expect(flash[:error]).to eq("You signed into Google with bar@gmail.com. " \
            "Please sign in with foo@gmail.com instead.")
        end
      end
    end
  end

  context "when client_error is returned from /token" do
    let!(:config) { create(:gdrive_config, org_user_id: "foo@gmail.com") }

    it "redirects with error" do
      with_env("STUB_SESSION_G_XSRF_TOKEN" => "P5JPu/n1QyYvkdEr3zgyHQ==") do
        VCR.use_cassette("gdrive/setup/callback/client_error") do
          get("/gdrive/setup/auth/callback", params: callback_payload)
          expect(response).to redirect_to(redirect_url)
          expect(flash[:error]).to match("There is a problem with your Google Drive connection. " \
            "Please contact Gather support.")
        end
      end
    end
  end

  context "when oauth flow is cancelled by user" do
    let(:callback_payload) do
      {
        "error" => "access_denied",
        "state" => "{\"community_id\":#{Defaults.community.id},\"session_id\":\"S03BSk1qW/wSZ6yyP9rXyA==\"," \
          "\"current_uri\":\"#{redirect_url}\"}"
      }
    end

    it "redirects with error" do
      get("/gdrive/setup/auth/callback", params: callback_payload)
      expect(response).to redirect_to(redirect_url)
      expect(flash[:error]).to eq("It looks like you cancelled the Google authentication flow.")
    end
  end
end
