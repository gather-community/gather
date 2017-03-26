require 'rails_helper'

RSpec.describe CustomFields::Entries::BasicEntry, type: :model do
  let(:field) { CustomFields::Fields::EnumField.new(key: "foo", options: %w(a b), required: true) }
  let(:entry) { described_class.new(field: field, hash: {foo: "b"}) }

  it "should delegate field methods" do
    expect(entry.key).to eq field.key
    expect(entry.type).to eq field.type
    expect(entry.options).to eq field.options
    expect(entry.required).to be field.required
  end

  describe "defaults" do
    let(:field) { CustomFields::Fields::StringField.new(key: "foo", default: "bar") }

    context "when initialized with empty hash" do
      let(:entry) { described_class.new(field: field, hash: {}) }

      it "should set key in hash to default and return default as value" do
        expect(entry.hash).to eq({foo: "bar"})
        expect(entry.value).to eq "bar"
      end
    end

    context "when initialized with explicit nil value" do
      let(:entry) { described_class.new(field: field, hash: {foo: nil}) }

      it "should still use default" do
        expect(entry.hash).to eq({foo: "bar"})
        expect(entry.value).to eq "bar"
      end
    end

    context "when initialized with non-nil value" do
      let(:entry) { described_class.new(field: field, hash: {foo: "baz"}) }

      it "should ignore default" do
        expect(entry.hash).to eq({foo: "baz"})
        expect(entry.value).to eq "baz"
      end
    end
  end

  describe "input_params" do
    context "for string field" do
      let(:field) { CustomFields::Fields::StringField.new(key: "foo") }
      let(:entry) { described_class.new(field: field, hash: {foo: "bar"}) }

      it "should return empty hash" do
        expect(entry.input_params).to eq({as: :string, input_html: {value: "bar"}})
      end
    end

    context "for enum field" do
      let(:field) { CustomFields::Fields::EnumField.new(key: "foo", options: %w(a b)) }
      let(:entry) { described_class.new(field: field, hash: {foo: "b"}) }

      it "should return collection" do
        expect(entry.input_params).to eq({as: :select, collection: %w(a b), selected: "b"})
      end
    end

    context "for boolean field" do
      let(:field) { CustomFields::Fields::BooleanField.new(key: "foo") }
      let(:entry) { described_class.new(field: field, hash: {foo: true}) }

      it "should return as boolean" do
        expect(entry.input_params).to eq({as: :boolean, input_html: {checked: true}})
      end
    end

    context "for text field" do
      let(:field) { CustomFields::Fields::TextField.new(key: "foo") }
      let(:entry) { described_class.new(field: field, hash: {foo: "bar"}) }

      it "should return empty hash" do
        expect(entry.input_params).to eq({as: :text, input_html: {value: "bar"}})
      end
    end
  end
end
