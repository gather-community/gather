# frozen_string_literal: true

require "rails_helper"

describe Utils::Nav::CustomizationParser do
  subject(:result) { Utils::Nav::CustomizationParser.new(str).parse }

  context "No customizations" do
    let(:str) { nil }
    it { is_expected.to eq({}) }
  end

  context "One item" do
    let(:str) { "[Google](http://www.google.com)" }
    it { is_expected.to eq("Google" => "http://www.google.com") }
  end

  context "Two items" do
    let(:str) { "[Google](http://www.google.com)[Yahoo](http://www.yahoo.com)" }
    it { is_expected.to eq("Google" => "http://www.google.com", "Yahoo" => "http://www.yahoo.com") }
    it { expect(result.keys).to eq(%w[Google Yahoo]) }
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

  context "One item with extra stuff" do
    let(:str) { "ignore-me [Google](http://www.google.com) ignore me too!" }
    it { is_expected.to eq("Google" => "http://www.google.com") }
  end

  context "complicated url" do
    let(:str) { "[Somewhere out there](http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21)" }
    it { is_expected.to eq("Somewhere out there" => "http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21") }
  end
end
