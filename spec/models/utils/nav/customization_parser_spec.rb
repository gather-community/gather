# frozen_string_literal: true

require "rails_helper"

describe Utils::Nav::CustomizationParser do
  subject(:result) { Utils::Nav::CustomizationParser.new(str).send(:parse) }

  context "no customizations" do
    let(:str) { nil }
    it { is_expected.to eq({}) }
  end

  context "one item" do
    let(:str) { "[Google](http://www.google.com)" }
    it { is_expected.to eq("Google" => "http://www.google.com") }
  end

  context "two items, one blank" do
    let(:str) { "[Google](http://www.google.com)[Meals]()" }
    it { is_expected.to eq("Google" => "http://www.google.com", "Meals" => "") }
  end

  context "invalid data" do
    let(:str) { "this is a bunch of gumph: []()" }
    it { is_expected.to eq({}) }
  end

  context "almost valid data" do
    let(:str) { "[Google](http://www.google.com*)" }
    it { is_expected.to eq({}) }
  end

  context "space in the middle" do
    let(:str) { "[Google] (http://www.google.com)" }
    it { is_expected.to eq("Google" => "http://www.google.com") }
  end

  context "stuff in the middle" do
    let(:str) { "[Google]in the way(http://www.google.com)" }
    it { is_expected.to eq({}) }
  end

  context "one item with extra stuff" do
    let(:str) { "ignore-me [Google](http://www.google.com) ignore me too!" }
    it { is_expected.to eq("Google" => "http://www.google.com") }
  end

  context "complicated url" do
    let(:str) do
      "[Somewhere out there](http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21)"
    end

    it do
      is_expected.to eq("Somewhere out there" =>
        "http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21")
    end
  end
end
