require 'rails_helper'

RSpec.describe CustomFields::Instance, type: :model do
  let(:spec_data) { [
    {key: "fruit", type: "enum", options: %w(apple banana peach), required: true},
    {key: "info", type: "group", fields: [
      {key: "complete", type: "boolean"},
      {key: "comment", type: "string"}
    ]}
  ] }
  let(:instance) { described_class.new(spec_data: spec_data, instance_data: instance_data) }
  let(:instance_data) { {"fruit" => "peach", "info" => {"complete" => true, "comment" => "hi!"}} }

  describe "constructor" do
    context "with initial instance data" do
      it "should create entries with appropriate data in order of spec" do
        expect(instance.entries[0].key).to eq :fruit
        expect(instance.entries[0].value).to eq "peach"
        expect(instance.entries[1].key).to eq :info
        expect(instance.entries[1].entries[0].key).to eq :complete
        expect(instance.entries[1].entries[0].value).to be true
        expect(instance.entries[1].entries[1].key).to eq :comment
        expect(instance.entries[1].entries[1].value).to eq "hi!"
      end
    end

    context "with empty instance data" do
      let(:instance_data) { {} }

      it "should work but have nil entries" do
        expect(instance.entries.size).to eq 2
        expect(instance.entries[0].key).to eq :fruit
        expect(instance.entries[0].value).to be_nil
        expect(instance.entries[1].key).to eq :info
        expect(instance.entries[1].entries[0].key).to eq :complete
        expect(instance.entries[1].entries[0].value).to be_nil
        expect(instance.entries[1].entries[1].key).to eq :comment
        expect(instance.entries[1].entries[1].value).to be_nil
      end
    end

    context "with nil instance data" do
      let(:instance_data) { nil }

      it "should error" do
        expect { instance }.to raise_error(ArgumentError)
      end
    end
  end

  describe "accessor" do
    describe "method call style" do
      it "should work for valid key" do
        expect(instance.fruit).to eq "peach"
        expect(instance.info.comment).to eq "hi!"
      end

      it "should raise NoMethodError for invalid key" do
        expect { instance.baz }.to raise_error(NoMethodError)
      end
    end

    describe "[] style" do
      it "should work for valid key" do
        expect(instance["fruit"]).to eq "peach"
        expect(instance["info"][:complete]).to be true
      end

      it "should return nil for invalid key" do
        expect(instance["baz"]).to be_nil
      end
    end
  end

  describe "update" do
    context "with initial instance data" do
      it "should update entries AND original hash" do
        instance.update(foo: "apple", bar: "junk")
        expect(instance.foo).to eq "apple"
        expect(instance.bar).to eq "junk"
        expect(instance_data).to eq({bar: "junk", foo: "apple"}) # Keys are symbolized in constructor
      end

      it "should work with partial updates" do
        instance.update(foo: "apple")
        expect(instance.foo).to eq "apple"
        expect(instance.bar).to eq "stuff"
        expect(instance_data).to eq({bar: "stuff", foo: "apple"})
      end

      it "should work with string keys" do
        instance.update("foo" => "apple", "bar" => "junk")
        expect(instance.foo).to eq "apple"
        expect(instance.bar).to eq "junk"
        expect(instance_data).to eq({bar: "junk", foo: "apple"})
      end

      it "should ignore irrelevant keys" do
        instance.update(foo: "apple", qux: "junk")
        expect(instance.foo).to eq "apple"
        expect(instance.bar).to eq "stuff"
        expect { instance.qux }.to raise_error(NoMethodError)
        expect(instance_data).to eq({bar: "stuff", foo: "apple"})
      end
    end

    context "with no initial instance data" do
      let(:instance_data) { {} }

      it "should still update original hash" do
        instance.update(foo: "apple")
        expect(instance_data).to eq({foo: "apple"})
        expect(instance.foo).to eq "apple"
      end
    end
  end
end
