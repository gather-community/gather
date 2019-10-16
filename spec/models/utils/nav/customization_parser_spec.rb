# frozen_string_literal: true

require "rails_helper"

describe Utils::Nav::CustomizationParser do
  it "No customizations" do
    parser = Utils::Nav::CustomizationParser.new(nil)
    expect(parser.parse).to eq({})
  end
  it "One item" do
    parser = Utils::Nav::CustomizationParser.new("[Google](http://www.google.com)")
    expect(parser.parse).to eq("Google" => "http://www.google.com")
  end
  it "Two items" do
    parser = Utils::Nav::CustomizationParser.new("[Google](http://www.google.com)[Yahoo](http://www.yahoo.com)")
    expect(parser.parse).to eq("Google" => "http://www.google.com", "Yahoo" => "http://www.yahoo.com")
  end
  it "invalid data" do
    parser = Utils::Nav::CustomizationParser.new("this is a bunch of gumph: []()")
    expect(parser.parse).to eq({})
  end
  it "almost valid data" do
    parser = Utils::Nav::CustomizationParser.new("[Google](http://www.google.com*)")
    expect(parser.parse).to eq({})
  end
  it "space in the middle" do
    parser = Utils::Nav::CustomizationParser.new("[Google] (http://www.google.com)")
    expect(parser.parse).to eq("Google" => "http://www.google.com")
  end
  it "stuff in the middle" do
    parser = Utils::Nav::CustomizationParser.new("[Google]in the way(http://www.google.com)")
    expect(parser.parse).to eq({})
  end
  it "One item with extra stuff" do
    parser = Utils::Nav::CustomizationParser.new("ignore-me [Google](http://www.google.com) ignore me too!")
    expect(parser.parse).to eq("Google" => "http://www.google.com")
  end
  it "complicated url" do
    parser = Utils::Nav::CustomizationParser.new("[Somewhere out there](http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21)")
    expect(parser.parse).to eq("Somewhere out there" => "http://groucho:swordfish@somewhere.com?foo=bar&baz=frobozz+and+more%21")
  end
  it "long complicated url" do
    parser = Utils::Nav::CustomizationParser.new("[GoogleGoo](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&uact=8&ved=2ahUKEwjO9Jqjs6HlAhWiHzQIHeWYALcQFjAAegQIBRAB&url=https%3A%2F%2Fstackoverflow.com%2Fquestions%2F18273148%2Fphp-and-in-urls-whats-the-difference&usg=AOvVaw0zjQPfeFMMHHch_nuHDE7U)")
    expect(parser.parse).to eq("GoogleGoo" => "https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&uact=8&ved=2ahUKEwjO9Jqjs6HlAhWiHzQIHeWYALcQFjAAegQIBRAB&url=https%3A%2F%2Fstackoverflow.com%2Fquestions%2F18273148%2Fphp-and-in-urls-whats-the-difference&usg=AOvVaw0zjQPfeFMMHHch_nuHDE7U")
  end
end
