require 'rails_helper'

RSpec.describe CustomFields::Config, type: :model do
  let(:spec_data) { [
    {
      "key" => "foo",
      "type" => "enum",
      "options" => %w(apple banana peach),
      "required" => true
    },{
      "key" => "bar",
      "type" => "text",
      "required" => false
    }
  ] }
  let(:config) { described_class.new(spec_data: spec_data, config_data: config_data) }

  describe "constructor" do
    context "with initial config data" do
      let(:config_data) { {"bar" => "stuff", "foo" => "peach"} }

      it "should create entries with appropriate data in order of spec" do
        expect(config.entries[0].key).to eq :foo
        expect(config.entries[0].value).to eq "peach"
        expect(config.entries[1].key).to eq :bar
        expect(config.entries[1].value).to eq "stuff"
      end
    end

    context "with empty config data" do
      let(:config_data) { {} }

      it "should work but have nil entries" do
        expect(config.entries.size).to eq 2
        expect(config.entries[0].key).to eq :foo
        expect(config.entries[0].value).to be_nil
        expect(config.entries[1].key).to eq :bar
        expect(config.entries[1].value).to be_nil
      end
    end

    context "with nil config data" do
      let(:config_data) { nil }

      it "should error" do
        expect { config }.to raise_error(ArgumentError)
      end
    end
  end

  describe "accessor" do
    let(:config_data) { {"bar" => "stuff", "foo" => "peach"} }

    describe "method call style" do
      it "should work for valid key" do
        expect(config.foo).to eq "peach"
      end

      it "should raise NoMethodError for invalid key" do
        expect { config.baz }.to raise_error(NoMethodError)
      end
    end

    describe "[] style" do
      it "should work for valid key" do
        expect(config["foo"]).to eq "peach"
      end

      it "should return nil for invalid key" do
        expect(config["baz"]).to be_nil
      end
    end
  end

  describe "update" do
    context "with initial config data" do
      let(:config_data) { {"bar" => "stuff", "foo" => "peach"} }

      it "should update entries AND original hash" do
        config.update(foo: "apple", bar: "junk")
        expect(config.foo).to eq "apple"
        expect(config.bar).to eq "junk"
        expect(config_data).to eq({bar: "junk", foo: "apple"}) # Keys are symbolized in constructor
      end

      it "should work with partial updates" do
        config.update(foo: "apple")
        expect(config.foo).to eq "apple"
        expect(config.bar).to eq "stuff"
        expect(config_data).to eq({bar: "stuff", foo: "apple"})
      end

      it "should work with string keys" do
        config.update("foo" => "apple", "bar" => "junk")
        expect(config.foo).to eq "apple"
        expect(config.bar).to eq "junk"
        expect(config_data).to eq({bar: "junk", foo: "apple"})
      end

      it "should ignore irrelevant keys" do
        config.update(foo: "apple", qux: "junk")
        expect(config.foo).to eq "apple"
        expect(config.bar).to eq "stuff"
        expect { config.qux }.to raise_error(NoMethodError)
        expect(config_data).to eq({bar: "stuff", foo: "apple"})
      end
    end

    context "with no initial config data" do
      let(:config_data) { {} }

      it "should still update original hash" do
        config.update(foo: "apple")
        expect(config_data).to eq({foo: "apple"})
        expect(config.foo).to eq "apple"
      end
    end
  end
end
