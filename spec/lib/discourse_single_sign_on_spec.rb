# frozen_string_literal: true

require "rails_helper"

describe DiscourseSingleSignOn do
  let(:secret) { "d836444a9e4084d5b224a60c208dce14" }

  # Uses the worked example from https://meta.discourse.org/t/official-single-sign-on-for-discourse-sso/13045
  context "with valid payload and separate return url" do
    let(:sso) do
      described_class.new(
        payload: "bm9uY2U9Y2I2ODI1MWVlZmI1MjExZTU4YzAwZmYxMzk1ZjBjMGI=\n",
        signature: "2828aa29899722b35a2f191d34ef9b3ce695e0e6eeec47deb46d588d70c7cb56",
        secret: secret,
        return_url: "https://x.co/sso_login"
      )
    end

    it "decodes, allows accessors to be set, and returns the correct return URL" do
      sso.name = "sam"
      sso.external_id = "hello123"
      sso.email = "test@test.com"
      sso.username = "samsam"
      sso.require_activation = true
      expect(decode(sso.to_url)).to eq("email" => ["test@test.com"],
                                       "external_id" => ["hello123"],
                                       "name" => ["sam"],
                                       "nonce" => ["cb68251eefb5211e58c00ff1395f0c0b"],
                                       "username" => ["samsam"],
                                       "require_activation" => ["true"])
      expect(sso.to_url).to eq("https://x.co/sso_login?sso=ZW1haWw9dGVzdCU0MHRlc3QuY29tJmV4dGVybmFsX2lkPW" \
                               "hlbGxvMTIzJm5hbWU9c2FtJm5vbmNlPWNiNjgyNTFlZWZiNTIxMWU1OGMwMGZmMTM5NWYwYzBiJnJlcXVpcmVfYWN0aXZhdG" \
                               "lvbj10cnVlJnVzZXJuYW1lPXNhbXNhbQ%3D%3D&sig=bcd8a9c2c7fda7b756b9b4e36c905c1611e75ae8b0165497cbcd2" \
                               "a8d3eaf5db7")
    end
  end

  context "with valid payload including return url and custom fields" do
    let(:sso) do
      described_class.new(
        payload: "bm9uY2U9NDllYjU5NTU2NmQxYmUxNmI2NjZjMjRlMTM2YjcwMjkmcmV0dXJuX3Nzb191cmw9aHR0cH" \
                 "M6Ly9tYWlsLmdhdGhlci5jb29wL3Nzby9sb2dpbiZjdXN0b20ubmV4dD0vcG9zdG9yaXVzL2xpc3RzLw==",
        signature: "078d60ae03634b800dba380232908b212d5e2c1ba9944828f04f949902702ef0",
        secret: "ea3805afe17b6bae08fb2c056f1fdf632ac13960a9ef78bedfedadea1a108da6",
        return_url: "https://x.co/sso_login"
      )
    end

    it "decodes, allows accessors to be set, and returns the correct return URL" do
      sso.email = "tom@example.com"
      sso.external_id = "1234"
      sso.name = "Tom Smyth"
      sso.username = sso.name
      sso.custom_fields[:first_name] = "Tom"
      sso.custom_fields[:last_name] = "Smyth"
      expect(decode(sso.to_url)).to eq("email" => ["tom@example.com"],
                                       "external_id" => ["1234"],
                                       "name" => ["Tom Smyth"],
                                       "nonce" => ["49eb595566d1be16b666c24e136b7029"],
                                       "return_sso_url" => ["https://mail.gather.coop/sso/login"],
                                       "username" => ["Tom Smyth"],
                                       "custom.next" => ["/postorius/lists/"],
                                       "custom.first_name" => ["Tom"],
                                       "custom.last_name" => ["Smyth"])
      expect(sso.to_url).to eq("https://mail.gather.coop/sso/login?sso=ZW1haWw9dG9tJTQwZXhhbXBsZS5jb20mZXh0" \
                               "ZXJuYWxfaWQ9MTIzNCZuYW1lPVRvbStTbXl0aCZub25jZT00OWViNTk1NTY2ZDFiZTE2YjY2NmMyNGUxMzZiNzAyOSZyZXR1c" \
                               "m5fc3NvX3VybD1odHRwcyUzQSUyRiUyRm1haWwuZ2F0aGVyLmNvb3AlMkZzc28lMkZsb2dpbiZ1c2VybmFtZT1Ub20rU215dG" \
                               "gmY3VzdG9tLm5leHQ9JTJGcG9zdG9yaXVzJTJGbGlzdHMlMkYmY3VzdG9tLmZpcnN0X25hbWU9VG9tJmN1c3RvbS5sYXN0X25" \
                               "hbWU9U215dGg%3D&sig=340d7ed7d718b5b15350d9d3fccbb542e7918632567929dcc3b92edb8ff50b7e")
    end
  end

  context "with bad payload format" do
    let(:sso) do
      described_class.new(
        payload: "foo@bar",
        signature: "078d60ae03634b800dba380232908b212d5e2c1ba9944828f04f949902702ef0",
        secret: secret,
        return_url: "https://x.co/sso_login"
      )
    end

    it "raises error" do
      expect { sso }.to raise_error(
        DiscourseSingleSignOn::ParseError,
        "Invalid chars in SSO field.\n\npayload: foo@bar"
      )
    end
  end

  context "with bad signature format" do
    let(:sso) do
      described_class.new(
        payload: "bm9uY2U9Y2I2ODI1MWVlZmI1MjExZTU4YzAwZmYxMzk1ZjBjMGI=",
        signature: "aaaaaa29899722b35a2f191d34ef9b3ce695e0e6eeec47deb46d588d70c7cb56",
        secret: secret,
        return_url: "https://x.co/sso_login"
      )
    end

    it "raises error" do
      expect { sso }.to raise_error(
        DiscourseSingleSignOn::SignatureError,
        "Bad signature for payload.\n\n" \
        "payload: bm9uY2U9Y2I2ODI1MWVlZmI1MjExZTU4YzAwZmYxMzk1ZjBjMGI=\n\n" \
        "sig: aaaaaa29899722b35a2f191d34ef9b3ce695e0e6eeec47deb46d588d70c7cb56\n\n" \
        "expected sig: 1ce1494f94484b6f6a092be9b15ccc1cdafb1f8460a3838fbb0e0883c4390471"
      )
    end
  end

  context "with blank payload" do
    let(:sso) do
      described_class.new(
        payload: "",
        signature: "aaaaaa29899722b35a2f191d34ef9b3ce695e0e6eeec47deb46d588d70c7cb56",
        secret: secret,
        return_url: "https://x.co/sso_login"
      )
    end

    it "raises error" do
      expect { sso }.to raise_error(
        DiscourseSingleSignOn::ParseError, "Payload and signature both required if either given"
      )
    end
  end

  context "with blank signature" do
    let(:sso) do
      described_class.new(
        payload: "xxx",
        signature: "",
        secret: secret,
        return_url: "https://x.co/sso_login"
      )
    end

    it "raises error" do
      expect { sso }.to raise_error(
        DiscourseSingleSignOn::ParseError, "Payload and signature both required if either given"
      )
    end
  end

  context "with no payload or signature and manually set attributes" do
    let(:sso) do
      described_class.new(secret: secret, return_url: "https://x.co/sso_update")
    end

    it "generates correct URL" do
      sso.email = "phil@thesphinx.net"
      sso.external_id = "1234"
      sso.name = "Phil Borx"
      expect(decode(sso.to_url)).to eq("email" => ["phil@thesphinx.net"],
                                       "external_id" => ["1234"],
                                       "name" => ["Phil Borx"])
      expect(sso.to_url).to eq("https://x.co/sso_update?sso=ZW1haWw9cGhpbCU0MHRoZXNwaGlueC5uZXQmZXh0ZXJu" \
                               "YWxfaWQ9MTIzNCZuYW1lPVBoaWwrQm9yeA%3D%3D&sig=2025743556c46a691d73a7493e6e303bd0f346a414255c5729" \
                               "2181571bd3ebc9")
    end
  end

  def decode(url)
    CGI.parse(Base64.decode64(CGI.parse(URI.parse(url).query)["sso"][0]))
  end
end
