# frozen_string_literal: true

require "rails_helper"

describe "single sign on" do
  # We create an admin so they can impersonate. Otherwise behavior should be the same.
  let!(:actor) { create(:admin, id: 1234, first_name: "Tom", last_name: "Smyth", email: "tom@example.com") }
  let(:valid_incoming_url) do
    qs = Rack::Utils.build_query(return_sso_url: "https://example.com/sso/login", nonce: "xyz")
    payload = Base64.strict_encode64(qs)
    sig = OpenSSL::HMAC.hexdigest("sha256", Settings.single_sign_on.secret, payload)
    "/sso?sso=#{CGI.escape(payload)}&sig=#{sig}"
  end
  let(:valid_redirect) do
    "https://example.com/sso/login?sso=ZW1haWw9dG9tJTQwZXhhbXBsZS5jb20mZXh0ZXJuYWxfaW"\
      "Q9MTIzNCZuYW1lPVRvbStTbXl0aCZub25jZT14eXomcmV0dXJuX3Nzb191cmw9aHR0cHMlM0ElMkYlMkZleGFtcGx"\
      "lLmNvbSUyRnNzbyUyRmxvZ2luJnVzZXJuYW1lPVRvbStTbXl0aCZjdXN0b20uZmlyc3RfbmFtZT1Ub20mY3VzdG9t"\
      "Lmxhc3RfbmFtZT1TbXl0aA%3D%3D&sig=5e92db782d30080166aa52a145cb5d5f8210a9eba7a3e1af6bd157f954ddc2fe"
  end

  context "with signed in user" do
    before do
      # No subdomain
      login_as(actor, scope: :user)
    end

    shared_examples_for "redirects appropriately" do
      scenario do
        visit(valid_incoming_url)
        expect(current_url).to eq(valid_redirect)
      end
    end

    context "with valid data" do
      context "when not impersonating" do
        it_behaves_like "redirects appropriately"
      end

      context "when impersonating" do
        let!(:user2) { create(:user, id: 1235, first_name: "X", last_name: "Z", email: "x@example.com") }

        before do
          visit("/users/1235")
          click_link("Impersonate")
        end

        it_behaves_like "redirects appropriately"
      end
    end

    context "with errant data" do
      scenario "returns error" do
        visit("/sso?sso=&sig=")
        expect(page.body).to eq("Payload and signature are required")
      end
    end

    context "with unauthorized user" do
      let(:actor) { create(:user, :inactive) }

      scenario "returns error" do
        visit("/sso?sso=xxx&sig=yyy")
        expect(page).to have_content("You are not permitted to view that page")
      end
    end
  end

  context "without signed in user" do
    it "redirects to home, allows sign in, then redirects" do
      visit(valid_incoming_url)
      click_on("Sign in with Password")
      fill_in("Email Address", with: "tom@example.com")
      fill_in("Password", with: FactoryBot::DEFAULT_PASSWORD)
      click_button("Sign In")
      expect(current_url).to eq(valid_redirect)
    end
  end
end
