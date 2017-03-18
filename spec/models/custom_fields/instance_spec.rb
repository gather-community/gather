require 'rails_helper'

RSpec.describe CustomFields::Instance, type: :model do
  let(:spec_data) { [
    {key: "fruit", type: "enum", options: %w(apple banana peach), required: true},
    {key: "info", type: "group", fields: [
      {key: "complete", type: "boolean"},
      {key: "comment", type: "string"}
    ]}
  ] }
  let(:spec) { CustomFields::Spec.new(spec_data) }
  let(:instance) { described_class.new(
    spec: spec,
    instance_data: instance_data,
    model_i18n_key: "mod",
    attrib_name: "att"
  ) }
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

    context "with irrelevant keys" do
      let(:instance_data) { {fruit: "peach", info: {complete: true, comment: "hi!"}, qux: 1} }

      it "should ignore the extra key but preserve the hash" do
        expect(instance.entries.map(&:key)).to contain_exactly(:fruit, :info)
        expect(instance_data.keys).to contain_exactly(:fruit, :info, :qux)
      end
    end

    context "with nil instance data" do
      let(:instance_data) { nil }

      it "should error" do
        expect { instance }.to raise_error(ArgumentError)
      end
    end

    context "with malformed instance data" do
      let(:instance_data) { {fruit: "apple", info: "hi!"} }

      it "should error" do
        expect { instance }.to raise_error(ArgumentError)
      end
    end
  end

  describe "getters" do
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

  describe "setters" do
    describe "method call style" do
      it "should work for valid key" do
        instance.fruit = "apple"
        expect(instance.fruit).to eq "apple"
        expect(instance.info.comment).to eq "hi!"
      end

      it "should work for group with hash" do
        instance.info = {comment: "yo"}
        expect(instance.info.comment).to eq "yo"
      end

      it "should raise NoMethodError for invalid key" do
        expect { instance.baz = "foo" }.to raise_error(NoMethodError)
      end
    end

    describe "[] style" do
      it "should work for valid key" do
        instance["fruit"] = "apple"
        expect(instance["fruit"]).to eq "apple"
        expect(instance["info"][:complete]).to be true
      end

      it "should work for group with hash" do
        instance["info"] = {comment: "yo", complete: false}
        expect(instance["info"][:comment]).to eq "yo"
        expect(instance["info"][:complete]).to be false
      end

      it "should not successfully set value invalid key" do
        instance["baz"] = "apple"
        expect(instance["baz"]).to be_nil
      end
    end
  end

  describe "update via hash" do
    context "with initial instance data" do
      it "should update entries AND original hash" do
        instance.update(fruit: "apple", info: {complete: false, comment: "bye!"})
        expect(instance.fruit).to eq "apple"
        expect(instance.info.complete).to be false
        expect(instance.info.comment).to eq "bye!"
        expect(instance_data).to eq({fruit: "apple", info: {comment: "bye!", complete: false}})
      end

      it "should work with partial updates" do
        instance.update(fruit: "apple")
        expect(instance.fruit).to eq "apple"
        expect(instance.info.complete).to be true
        expect(instance.info.comment).to eq "hi!"
        expect(instance_data).to eq({fruit: "apple", info: {comment: "hi!", complete: true}})
      end

      it "should work with string keys" do
        instance.update("fruit" => "apple", "info" => {"complete" => false, "comment" => "bye!"})
        expect(instance.fruit).to eq "apple"
        expect(instance.info.complete).to be false
        expect(instance.info.comment).to eq "bye!"
        expect(instance_data).to eq({fruit: "apple", info: {comment: "bye!", complete: false}})
      end

      it "should ignore irrelevant keys" do
        instance.update(fruit: "apple", qux: "junk")
        expect(instance.fruit).to eq "apple"
        expect { instance.qux }.to raise_error(NoMethodError)
        expect(instance_data).to eq({fruit: "apple", info: {comment: "hi!", complete: true}})
      end

      it "should handle malformed data" do
        expect { instance.update(2) }.to raise_error(ArgumentError)
        expect { instance.update(fruit: "apple", info: "hi!") }.to raise_error(ArgumentError)
      end
    end

    context "with no initial instance data" do
      let(:instance_data) { {} }

      it "should still update original hash" do
        instance.update(fruit: "apple")
        expect(instance_data).to eq({fruit: "apple", info: {comment: nil, complete: nil}})
        expect(instance.fruit).to eq "apple"
      end
    end
  end
end
