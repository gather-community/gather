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
      {"key" => "info", "type" => "group", "fields" => [
        {"key" => "complete", "type" => "boolean", "default" => true},
        {"key" => "comment", "type" => "string", "default" => "foo"},
        {"key" => "tree", "type" => "group", "fields" => [
          {"key" => "species", "type" => "enum", "options" => %w(spruce pine)},
          {"key" => "height", "type" => "integer", "required" => true}
        ]},
        {"key" => "count", "type" => "integer"}
      ]},
      {"key" => "bar", "type" => "text", "required" => false}
    ])}

    it "should create fields and sub specs" do
      expect(spec.fields[0].key).to eq :fruit
      expect(spec.fields[1].fields[0].key).to eq :complete
      expect(spec.fields[1].fields[0].default).to be true
      expect(spec.fields[1].fields[1].key).to eq :comment
      expect(spec.fields[1].fields[1].default).to eq "foo"
      expect(spec.fields[1].fields[2].fields[0].key).to eq :species
      expect(spec.fields[1].fields[2].fields[1].key).to eq :height
      expect(spec.fields[1].fields[3].key).to eq :count
      expect(spec.fields[2].key).to eq :bar
    end
  end
end
