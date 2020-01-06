# frozen_string_literal: true

require "rails_helper"

describe "single sign on" do
  context "with signed in user" do
    let(:actor) { create(:user, id: 1234, first_name: "Tom", last_name: "Smyth", email: "tom@example.com") }

    before do
      # No subdomain
      sign_in(actor)
    end

    context "with valid data" do
      it "redirects to requested URL" do
        payload = "bm9uY2U9NDllYjU5NTU2NmQxYmUxNmI2NjZjMjRlMTM2YjcwMjkmcmV0dXJuX3Nzb191cmw9aHR0cH"\
          "M6Ly9tYWlsLmdhdGhlci5jb29wL3Nzby9sb2dpbiZjdXN0b20ubmV4dD0vcG9zdG9yaXVzL2xpc3RzLw=="
        signature = "078d60ae03634b800dba380232908b212d5e2c1ba9944828f04f949902702ef0"
        get("/sso", params: {sso: payload, sig: signature})

        redirect = "https://mail.gather.coop/sso/login?sso=ZW1haWw9dG9tJTQwZXhhbXBsZS5jb20mZXh0"\
          "ZXJuYWxfaWQ9MTIzNCZuYW1lPVRvbStTbXl0aCZub25jZT00OWViNTk1NTY2ZDFiZTE2YjY2NmMyNGUxMzZiNzAyOSZyZXR1c"\
          "m5fc3NvX3VybD1odHRwcyUzQSUyRiUyRm1haWwuZ2F0aGVyLmNvb3AlMkZzc28lMkZsb2dpbiZ1c2VybmFtZT1Ub20rU215dG"\
          "gmY3VzdG9tLm5leHQ9JTJGcG9zdG9yaXVzJTJGbGlzdHMlMkYmY3VzdG9tLmZpcnN0X25hbWU9VG9tJmN1c3RvbS5sYXN0X25"\
          "hbWU9U215dGg%3D&sig=340d7ed7d718b5b15350d9d3fccbb542e7918632567929dcc3b92edb8ff50b7e"
        expect(response).to redirect_to(redirect)
      end
    end

    context "with errant data" do
      it "returns 422" do
        get("/sso", params: {sso: "", sig: ""})
        expect(response.status).to eq(422)
        expect(response.body).to eq("Payload and signature are required")
      end
    end

    context "with unauthorized user" do
      let(:actor) { create(:user, :inactive) }

      it "returns 403" do
        get("/sso", params: {sso: "xxx", sig: "yyy"})
        expect(response.status).to eq(403)
        expect(response.content_type).to eq("text/html; charset=utf-8")
        expect(response.body).to match(/You are not permitted to view that page/)
      end
    end
  end

  context "without signed in user" do
    it "redirects to home" do
      get("/sso", params: {sso: "xxx", sig: "yyy"})
      expect(response).to redirect_to("http://gather.localhost.tv:31337/?sign-in=1")
    end
  end
end
