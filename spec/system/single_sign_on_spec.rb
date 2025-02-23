# frozen_string_literal: true

require "rails_helper"

describe "single sign on" do
  # We create an admin so they can impersonate. Otherwise behavior should be the same.
  let!(:actor) { create(:admin, id: 1234, first_name: "Tom", last_name: "Smyth", email: "tom@example.com") }
  let(:subdomain) { nil }
  let(:cluster) { Defaults.cluster }
  let(:community) { Defaults.community }
  let(:secret_on_foreign_host) { Settings.single_sign_on.secret }
  let(:valid_incoming_url) do
    qs = Rack::Utils.build_query(return_sso_url: "https://example.com/sso/login", nonce: "xyz")
    payload = Base64.strict_encode64(qs)
    sig = OpenSSL::HMAC.hexdigest("sha256", secret_on_foreign_host, payload)
    host = [subdomain, Settings.url.host].compact.join(".")
    "#{Settings.url.protocol}://#{host}:#{Settings.url.port}/sso?sso=#{CGI.escape(payload)}&sig=#{sig}"
  end
  let(:valid_redirect) do
    # By the time we are testing the redirect, we can assume the secret on the foreign
    # host was correct.
    secret_for_redirect = secret_on_foreign_host
    payload = "ZW1haWw9dG9tJTQwZXhhbXBsZS5jb20mZXh0ZXJuYWxfaWQ9MTIzNCZuYW1lPVRvbStTbXl0aCZub25jZT14eXomc" \
              "mV0dXJuX3Nzb191cmw9aHR0cHMlM0ElMkYlMkZleGFtcGxlLmNvbSUyRnNzbyUyRmxvZ2luJnVzZXJuYW1lPVRvbS" \
              "tTbXl0aCZjdXN0b20uZmlyc3RfbmFtZT1Ub20mY3VzdG9tLmxhc3RfbmFtZT1TbXl0aA=="
    sig = OpenSSL::HMAC.hexdigest("sha256", secret_for_redirect, payload)
    "https://example.com/sso/login?sso=#{CGI.escape(payload)}&sig=#{sig}"
  end

  before do
    cluster.update!(sso_secret: "clustersecret")
    community.update!(sso_secret: "communitysecret")
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

    shared_examples_for "fails with bad signature" do
      scenario do
        visit(valid_incoming_url)
        expect(page).to have_content("Bad signature for payload.")
      end
    end

    shared_examples_for "fails with 403" do
      scenario do
        visit(valid_incoming_url)
        expect(page).to have_content("You are not permitted")
      end
    end

    context "with valid data" do
      context "when not impersonating" do
        # This is the same as if the actor is from a different community in the cluster.
        # The actor in this case is from the default community, but the subdomain AND secret
        # are for community2. In this case, we don't want to permit the SSO. This is accomplished
        # by limiting the policy so that a 403 is returned.
        context "with secret and subdomain for a different community in the cluster" do
          let(:community2) { create(:community, sso_secret: "community2secret") }
          let(:secret_on_foreign_host) { "community2secret" }
          let(:subdomain) { community2.slug }
          it_behaves_like "fails with 403"
        end

        context "with community secret and subdomain for a community in a different cluster" do
          let(:community2) { ActsAsTenant.with_tenant(create(:cluster)) { create(:community) } }
          let(:secret_on_foreign_host) { "communitysecret" }
          let(:subdomain) { community2.slug }
          it_behaves_like "fails with 403"
        end

        context "with global secret and apex domain" do
          let(:secret_on_foreign_host) { Settings.single_sign_on.secret }
          let(:subdomain) { nil }
          it_behaves_like "redirects appropriately"
        end

        context "with cluster secret and subdomain from that cluster" do
          let(:secret_on_foreign_host) { "clustersecret" }
          let(:subdomain) { community.slug }
          it_behaves_like "redirects appropriately"
        end

        context "with community secret and subdomain for that community" do
          let(:secret_on_foreign_host) { "communitysecret" }
          let(:subdomain) { community.slug }
          it_behaves_like "redirects appropriately"
        end

        context "with global secret and subdomain for a community" do
          let(:secret_on_foreign_host) { Settings.single_sign_on.secret }
          let(:subdomain) { community.slug }
          it_behaves_like "fails with bad signature"
        end

        context "with cluster secret and apex domain" do
          let(:secret_on_foreign_host) { "clustersecret" }
          let(:subdomain) { nil }
          it_behaves_like "fails with bad signature"
        end
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
        expect(page.body).to eq("Return URL not given")
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
