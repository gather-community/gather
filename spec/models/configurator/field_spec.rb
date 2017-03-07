require 'rails_helper'

RSpec.describe Configurator::Field, type: :model do
  let(:field) { described_class.new(key: "foo", type: "string") }

  it "should symbolize string params" do
    expect(field.key).to eq :foo
    expect(field.type).to eq :string
  end

  describe "input_params" do
    context "for string field" do
      it "should return empty hash" do
        expect(field.input_params).to eq({})
      end
    end

    context "for enum field" do
      let(:field) { described_class.new(key: "foo", type: "enum", options: %w(a b)) }

      it "should return collection" do
        expect(field.input_params).to eq({collection: %w(a b)})
      end
    end

    context "for boolean field" do
      let!(:field) { described_class.new(key: "foo", type: "boolean") }

      it "should return as boolean" do
        expect(field.input_params).to eq({as: :boolean})
      end
    end

    context "for text field" do
      let!(:field) { described_class.new(key: "foo", type: "text") }

      it "should return empty hash" do
        expect(field.input_params).to eq({as: :text})
      end
    end
  end
end
