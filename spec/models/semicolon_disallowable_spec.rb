# frozen_string_literal: true

require "rails_helper"

describe SemicolonDisallowable do
  class Test # rubocop:disable Style/Documentation
    include ActiveModel::Model
    include SemicolonDisallowable
    attr_accessor :foo, :bar, :baz

    disallow_semicolons :foo, :bar
  end

  context "with normal values" do
    subject(:object) { Test.new(foo: "Stuff", bar: "Things", baz: "Guff") }
    it { is_expected.to be_valid }
  end

  context "with semicolons" do
    subject(:object) { Test.new(foo: "Stuff; Fluff", bar: "Things; Kings", baz: "Guff; Puff") }

    it do
      is_expected.not_to be_valid
      expect(object.errors[:foo]).to eq(["Semicolons not allowed"])
      expect(object.errors[:bar]).to eq(["Semicolons not allowed"])
      expect(object.errors[:baz]).to be_empty
    end
  end
end
