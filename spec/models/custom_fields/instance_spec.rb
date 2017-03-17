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
    class_name: "mod",
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
        expect(instance_data).to eq({fruit: "apple"})
        expect(instance.fruit).to eq "apple"
      end
    end
  end

  describe "i18n_key" do
    let(:spec_data) { [
      {key: "alpha", type: "string", validation: {length: {maximum: 5}}},
      {key: "bravo", type: "group", fields: [
        {key: "charlie", type: "string", validation: {length: {minimum: 5}}}
      ]}
    ] }

    it "should be correct at all levels" do
      expect(instance.entries[0].i18n_key(:errors)).to eq "custom_fields.errors.mod.att.alpha"
      expect(instance.entries[1].i18n_key(:errors)).to eq "custom_fields.errors.mod.att.bravo._self"
      expect(instance.entries[1].entries[0].i18n_key(:errors)).to eq(
        "custom_fields.errors.mod.att.bravo.charlie")
    end
  end

  describe "validation" do
    context "nestedness" do
      let(:spec_data) { [
        {key: "alpha", type: "string", validation: {length: {maximum: 5}}},
        {key: "bravo", type: "group", fields: [
          {key: "charlie", type: "string", validation: {length: {minimum: 5}}}
        ]}
      ] }

      context "with all valid entries" do
        let(:instance_data) { {alpha: "xxx", bravo: {charlie: "xxxxxx"}} }

        it "shouldn't be invalid" do
          expect(instance.valid?).to be true
          expect(instance.errors[:alpha]).to eq []
          expect(instance.errors[:bravo]).to eq []
          expect(instance.bravo.errors[:charlie]).to eq []
        end
      end

      context "with multiple invalid entries" do
        let(:instance_data) { {alpha: "xxxxxx", bravo: {charlie: "xxx"}} }

        it "should set error on all invalid fields" do
          expect(instance.valid?).to be false
          expect(instance.errors[:alpha]).to eq ["is too long (maximum is 5 characters)"]
          expect(instance.errors[:bravo]).to eq ["is invalid"]
          expect(instance.bravo.errors[:charlie]).to eq ["is too short (minimum is 5 characters)"]
        end
      end

      context "with an invalid leaf entry only" do
        let(:instance_data) { {alpha: "xxx", bravo: {charlie: "xxx"}} }

        it "should set error on appropriate fields" do
          expect(instance.valid?).to be false
          expect(instance.errors[:alpha]).to eq []
          expect(instance.errors[:bravo]).to eq ["is invalid"]
          expect(instance.bravo.errors[:charlie]).to eq ["is too short (minimum is 5 characters)"]
        end
      end
    end

    describe "required fields" do
      let(:spec_data) { [
        {key: "alpha", type: "string", required: true}
      ] }

      context "with blank entry" do
        let(:instance_data) { {alpha: ""} }

        it "should set error" do
          expect(instance.valid?).to be false
          expect(instance.errors[:alpha]).to eq ["can't be blank"]
        end
      end

      context "with nil entry" do
        let(:instance_data) { {alpha: nil} }

        it "should set error" do
          expect(instance.valid?).to be false
          expect(instance.errors[:alpha]).to eq ["can't be blank"]
        end
      end

      context "with missing entry" do
        let(:instance_data) { {} }

        it "should set error" do
          expect(instance.valid?).to be false
          expect(instance.errors[:alpha]).to eq ["can't be blank"]
        end
      end
    end

    describe "multiple validations on one field and custom messages" do
      let(:spec_data) { [
        {key: "alpha", type: "string", validation: {
          length: {minimum: 5, message: "too short!"},
          format: {with: /\Ax/, message: "doesn't start with x!"}}
        }
      ] }
      let(:instance_data) { {alpha: "hi!"} }

      it "should set multiple error messages" do
        expect(instance.valid?).to be false
        expect(instance.errors[:alpha]).to eq ["too short!", "doesn't start with x!"]
      end
    end

    describe "enum inclusion" do
      let(:spec_data) { [
        {key: "alpha", type: "enum", options: %w(blue yellow)}
      ] }

      context "with value from list" do
        let(:instance_data) { {alpha: "blue"} }

        it "should not set error" do
          expect(instance.valid?).to be true
        end
      end

      context "with value not from list" do
        let(:instance_data) { {alpha: "green"} }

        it "should set error" do
          expect(instance.valid?).to be false
          expect(instance.errors[:alpha]).to eq ["is not included in the list"]
        end
      end
    end

    describe "with string keys" do
      let(:spec_data) { [
        {key: "alpha", type: "string", validation: {"length" => {"maximum" => 5}}}
      ] }
      let(:instance_data) { {alpha: "xxxxxx"} }

      it "should still work" do
        expect(instance.valid?).to be false
        expect(instance.errors[:alpha]).to eq ["is too long (maximum is 5 characters)"]
      end
    end

    describe "with custom i18n'd message" do
      let(:spec_data) { [
        {key: "alpha", type: "string", validation: {length: {maximum: 5, message: :foo}}},
      ] }
      let(:instance_data) { {alpha: "xxxxxx"} }

      it "should look up message in expected place" do
        original_translate = I18n.method(:translate)
        allow(I18n).to receive(:translate) do |key, options|
          if key == "custom_fields.errors.mod.att.alpha"
            expect(options[:default]).to eq %i(
              activemodel.errors.messages.foo
              activerecord.errors.messages.foo
              errors.messages.foo
            )
            "Teh error msg"
          else
            original_translate.call(key, options)
          end
        end
        expect(instance.valid?).to be false
        expect(instance.errors[:alpha]).to eq ["Teh error msg"]
      end
    end
  end
end
