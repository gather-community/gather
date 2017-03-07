require 'rails_helper'

RSpec.describe Configurator::Spec, type: :model do
  describe "constructor" do
    it "should error with nil argument" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  describe "keys" do
    let(:spec) { described_class.new([
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
    ])}

    it "should contain matching keys" do
      expect(spec.keys).to eq %i(foo bar)
    end
  end
end
