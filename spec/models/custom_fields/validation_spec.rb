require "rails_helper"

describe "custom field validation" do
  let(:spec) { CustomFields::Spec.new(spec_data) }
  let(:instance) { CustomFields::Instance.new(
    spec: spec,
    instance_data: instance_data,
    model_i18n_key: "mod",
    attrib_name: "att"
  ) }

  describe "i18n_key" do
    let(:spec_data) { [
      {key: "alpha", type: "string", validation: {length: {maximum: 5}}},
      {key: "bravo", type: "group", fields: [
        {key: "charlie", type: "string", validation: {length: {minimum: 5}}}
      ]}
    ] }
    let(:instance_data) { {"fruit" => "peach", "info" => {"complete" => true, "comment" => "hi!"}} }

    it "should be correct at all levels" do
      expect(instance.entries[0].i18n_key(:errors)).to eq :"custom_fields.errors.mod.att.alpha"
      expect(instance.entries[1].i18n_key(:errors)).to eq :"custom_fields.errors.mod.att.bravo._self"
      expect(instance.entries[1].entries[0].i18n_key(:errors)).to eq(
        :"custom_fields.errors.mod.att.bravo.charlie")
    end
  end

  describe "nestedness" do
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

  describe "with custom error message" do
    let(:spec_data) { [
      {key: "alpha", type: "string", validation: {length: {maximum: 5, message: :foo}}},
    ] }
    let(:instance_data) { {alpha: "xxxxxx"} }

    it "should look up message in expected place" do
      stub_translation(:"custom_fields.errors.mod.att.alpha.foo", "Teh error msg", expect_defaults: %i(
        activemodel.errors.messages.foo
        activerecord.errors.messages.foo
        errors.messages.foo
      ))
      expect(instance.valid?).to be false
      expect(instance.errors[:alpha]).to eq ["Teh error msg"]
    end
  end
end
