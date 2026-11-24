# frozen_string_literal: true

require "rails_helper"

describe CustomFields::Fields::LinkField do
  describe "url" do
    it "accepts paths and http(s) URLs" do
      %w[/admin/sso-secret https://example.com http://example.com/x].each do |url|
        expect(described_class.new(key: "foo", url: url).url).to eq(url)
      end
    end

    it "rejects URLs that could run script or leave the site's scheme" do
      bad_urls = ["javascript:alert(1)", "JavaScript:alert(1)", "data:text/html,hi", "//evil.com", "foo", nil]
      bad_urls.each do |url|
        expect { described_class.new(key: "foo", url: url) }.to raise_error(ArgumentError), url.inspect
      end
    end

    it "makes an admin-written spec with a bad link invalid" do
      spec = [{"key" => "foo", "type" => "link", "url" => "javascript:alert(1)"}]
      expect { CustomFields::Spec.new(spec) }.to raise_error(ArgumentError)
    end
  end

  describe "in an instance" do
    let(:spec) do
      CustomFields::Spec.new([
        {key: "name", type: "string"},
        {key: "info", type: "group", fields: [{key: "more", type: "link", url: "/more"}]}
      ])
    end
    let(:instance_data) { {} }
    let(:instance) do
      CustomFields::Instance.new(host: Object.new, spec: spec, instance_data: instance_data,
        model_i18n_key: "mod", attrib_name: "att")
    end

    it "stores no value and isn't a permitted param" do
      instance.update(name: "Jo", info: {more: "sneaky"})
      expect(instance.info.more).to be_nil
      expect(instance.hash).to eq(name: "Jo", info: {})
      expect(spec.permitted).to eq([:name, {info: []}])
    end
  end
end
