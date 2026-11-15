# frozen_string_literal: true

require "rails_helper"

describe Gather::WordMatch do
  describe ".words" do
    it "splits on whitespace and punctuation and removes accents" do
      expect(described_class.words("  Zoë  Nader-Jen o'brien (vegan) "))
        .to eq(%w[Zoe Nader Jen o brien vegan])
    end

    it "returns nothing for a blank query or one that's all punctuation" do
      expect(described_class.words(nil)).to eq([])
      expect(described_class.words("  ")).to eq([])
      expect(described_class.words("%_%")).to eq([])
    end

    it "leaves letters it doesn't know alone" do
      expect(described_class.words("Иван Straße")).to eq(%w[Иван Straße])
    end
  end

  describe ".condition" do
    def match?(text, word)
      text_sql = ActiveRecord::Base.sanitize_sql_array(["SELECT ?::text AS s", text])
      condition = described_class.condition("t.s", word)
      ActiveRecord::Base.connection.select_value("SELECT #{condition} FROM (#{text_sql}) t")
    end

    it "folds every character the same way in Postgres as in Ruby" do
      described_class::FOLD_FROM.each_char do |char|
        folded = described_class.words("x#{char}y").join(" ")
        expect(match?("x#{char}y", folded.split.last)).to be(true), "#{char.inspect} didn't fold the same"
      end
    end

    it "matches only at the start of a word" do
      expect(match?("Maple Grove", "gro")).to be(true)
      expect(match?("Maple Grove", "rove")).to be(false)
    end
  end
end
