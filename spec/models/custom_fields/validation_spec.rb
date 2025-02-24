# frozen_string_literal: true

require "rails_helper"

describe "custom field validation" do
  let(:spec) { CustomFields::Spec.new(spec_data) }
  let(:instance) do
    CustomFields::Instance.new(
      host: Object.new,
      spec: spec,
      instance_data: instance_data,
      model_i18n_key: "mod",
      attrib_name: "att"
    )
  end

  describe "i18n_key" do
    let(:spec_data) do
      [
        {key: "alpha", type: "string", validation: {length: {maximum: 5}}},
        {key: "bravo", type: "group", fields: [
          {key: "charlie", type: "string", validation: {length: {minimum: 5}}}
        ]}
      ]
    end
    let(:instance_data) { {"fruit" => "peach", "info" => {"complete" => true, "comment" => "hi!"}} }

    it "should be correct at all levels" do
      expect(instance.entries[0].i18n_key(:errors)).to eq(:"custom_fields.errors.mod.att.alpha")
      expect(instance.entries[1].i18n_key(:errors)).to eq(:"custom_fields.errors.mod.att.bravo._self")
      expect(instance.entries[1].entries[0].i18n_key(:errors)).to eq(
        :"custom_fields.errors.mod.att.bravo.charlie"
      )
    end
  end

  describe "nestedness" do
    let(:spec_data) do
      [
        {key: "alpha", type: "string", validation: {length: {maximum: 5}}},
        {key: "bravo", type: "group", fields: [
          {key: "charlie", type: "string", validation: {length: {minimum: 5}}}
        ]}
      ]
    end

    context "with all valid entries" do
      let(:instance_data) { {alpha: "xxx", bravo: {charlie: "xxxxxx"}} }

      it "shouldn't be invalid" do
        expect(instance).to be_valid
        expect(instance.errors[:alpha]).to eq([])
        expect(instance.errors[:bravo]).to eq([])
        expect(instance.bravo.errors[:charlie]).to eq([])
      end
    end

    context "with multiple invalid entries" do
      let(:instance_data) { {alpha: "xxxxxx", bravo: {charlie: "xxx"}} }

      it "should set error on all invalid fields" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq(["is too long (maximum is 5 characters)"])
        expect(instance.errors[:bravo]).to eq(["is invalid"])
        expect(instance.bravo.errors[:charlie]).to eq(["is too short (minimum is 5 characters)"])
      end
    end

    context "with an invalid leaf entry only" do
      let(:instance_data) { {alpha: "xxx", bravo: {charlie: "xxx"}} }

      it "should set error on appropriate fields" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq([])
        expect(instance.errors[:bravo]).to eq(["is invalid"])
        expect(instance.bravo.errors[:charlie]).to eq(["is too short (minimum is 5 characters)"])
      end
    end
  end

  describe "required fields" do
    let(:spec_data) do
      [
        {key: "alpha", type: "string", required: true}
      ]
    end

    context "with blank entry" do
      let(:instance_data) { {alpha: ""} }

      it "should set error" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq(["can't be blank"])
      end
    end

    context "with nil entry" do
      let(:instance_data) { {alpha: nil} }

      it "should set error" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq(["can't be blank"])
      end
    end

    context "with missing entry" do
      let(:instance_data) { {} }

      it "should set error" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq(["can't be blank"])
      end
    end
  end

  describe "multiple validations on one field and custom messages" do
    let(:spec_data) do
      [
        {key: "alpha", type: "string", validation: {
          length: {minimum: 5, message: "too short!"},
          format: {with: /\Ax/, message: "doesn't start with x!"}
        }}
      ]
    end
    let(:instance_data) { {alpha: "hi!"} }

    it "should set multiple error messages" do
      expect(instance).not_to be_valid
      expect(instance.errors[:alpha]).to eq(["too short!", "doesn't start with x!"])
    end
  end

  describe "enum inclusion" do
    let(:spec_data) do
      [
        {key: "alpha", type: "enum", options: %w[blue yellow]}
      ]
    end

    context "with value from list" do
      let(:instance_data) { {alpha: "blue"} }

      it "should not set error" do
        expect(instance).to be_valid
      end
    end

    context "with value not from list" do
      let(:instance_data) { {alpha: "green"} }

      it "should set error" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq(["is not included in the list"])
      end
    end
  end

  describe "email format" do
    let(:spec_data) { [{key: "alpha", type: "email"}] }

    context "with correct format" do
      let(:instance_data) { {alpha: "foo@bar.com"} }

      it "should not set error" do
        expect(instance).to be_valid
      end
    end

    context "with incorrect format" do
      let(:instance_data) { {alpha: "foo@bar"} }

      it "should set error" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq(["is invalid"])
      end
    end

    context "with nil value" do
      let(:instance_data) { {alpha: nil} }

      it "should not set error" do
        expect(instance).to be_valid
      end
    end
  end

  describe "url format" do
    let(:options) { {} }
    let(:spec_data) { [{key: "alpha", type: "url"}.merge(options)] }

    context "with correct format" do
      let(:instance_data) { {alpha: "https://junk.com"} }

      it "should not set error" do
        expect(instance).to be_valid
      end
    end

    context "with incorrect format" do
      let(:instance_data) { {alpha: "https://jun  kcom"} }

      it "should set error" do
        expect(instance).not_to be_valid
        expect(instance.errors[:alpha]).to eq(["is not a valid URL"])
      end
    end

    context "with host option" do
      let(:options) { {host: "paypal.me"} }

      context "with correct host" do
        let(:instance_data) { {alpha: "https://paypal.me/foo/bar?blah=foo"} }

        it "should not set error" do
          expect(instance).to be_valid
        end
      end

      context "with incorrect host" do
        let(:instance_data) { {alpha: "https://junk.com/foo/bar"} }

        it "should set error" do
          expect(instance).not_to be_valid
          expect(instance.errors[:alpha]).to eq(["must include 'paypal.me'"])
        end
      end
    end

    context "with nil value" do
      let(:instance_data) { {alpha: nil} }

      it "should not set error" do
        expect(instance).to be_valid
      end
    end
  end

  describe "with string keys" do
    let(:spec_data) do
      [
        {key: "alpha", type: "string", validation: {"length" => {"maximum" => 5}}}
      ]
    end
    let(:instance_data) { {alpha: "xxxxxx"} }

    it "should still work" do
      expect(instance).not_to be_valid
      expect(instance.errors[:alpha]).to eq(["is too long (maximum is 5 characters)"])
    end
  end

  describe "with custom error message" do
    let(:spec_data) do
      [
        {key: "alpha", type: "string", validation: {length: {maximum: 5, message: :foo}}}
      ]
    end
    let(:instance_data) { {alpha: "xxxxxx"} }

    it "should look up message in expected place" do
      expected_error_msg = "Translation missing. Options considered were:\n" \
                           "- en.custom_fields.errors.mod.att.alpha.foo\n" \
                           "- en.activemodel.errors.messages.foo\n" \
                           "- en.activerecord.errors.messages.foo\n" \
                           "- en.errors.messages.foo"
      expect(instance).not_to be_valid
      expect(instance.errors[:alpha]).to eq([expected_error_msg])
    end
  end
end
