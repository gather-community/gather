require 'rails_helper'

RSpec.describe CustomFields::Spec, type: :model do
  describe "constructor" do
    it "should error with nil argument" do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end

  describe "keys" do
    let(:spec) { described_class.new([
      {"key" => "fruit", "type" => "enum", "options" => %w(apple banana peach), "required" => true},
      {"key" => "info", "type" => "group", "items" => [
        {"key" => "complete", "type" => "boolean"},
        {"key" => "comment", "type" => "string"},
        {"key" => "tree", "type" => "group", "items" => [
          {"key" => "species", "type" => "enum", "options" => %w(spruce pine)},
          {"key" => "height", "type" => "integer", "required" => true}
        ]},
        {"key" => "count", "type" => "integer"}
      ]},
      {"key" => "bar", "type" => "text", "required" => false}
    ])}

    it "should create fields and sub specs" do
      expect(spec.items[0].key).to eq :fruit
      expect(spec.items[1].items[0].key).to eq :complete
      expect(spec.items[1].items[1].key).to eq :comment
      expect(spec.items[1].items[2].items[0].key).to eq :species
      expect(spec.items[1].items[2].items[1].key).to eq :height
      expect(spec.items[1].items[3].key).to eq :count
      expect(spec.items[2].key).to eq :bar
    end
  end
end
