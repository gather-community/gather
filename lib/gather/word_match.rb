# frozen_string_literal: true

module Gather
  # The rules for Gather's text searches (ApplicationRecord.matching_word_starts): each word of the query
  # must start a word of the text, so "ma gre" matches "Max Greenfelder" but "ax" doesn't. Case and
  # accents don't matter, and punctuation separates words, so "zoe" matches "Zoë" and "jen" matches
  # "Nader-Jenkins". Work::Shift's Elasticsearch search matches the same way.
  #
  # The query is folded in Ruby and the text in Postgres, using the same table of characters, so the
  # two always agree.
  module WordMatch
    # Characters that separate words, along with whitespace.
    PUNCTUATION = "-_.,;:!?()[]{}/\\|&@'\"#+*~%’"
    ACCENTED = "ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÝýÿŠšŽžČčĆćŁłŃńŚśŹźŻżĘęĄąŘřĚěŮů"
    UNACCENTED = "AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOOooooooUUUUuuuuYyySsZzCcCcLlNnSsZzZzEeAaRrEeUu"

    # Pairs up character by character, for Postgres's translate() and for FOLD_MAP.
    FOLD_FROM = PUNCTUATION + ACCENTED
    FOLD_TO = (" " * PUNCTUATION.length) + UNACCENTED
    FOLD_MAP = FOLD_FROM.chars.zip(FOLD_TO.chars).to_h.freeze
    FOLD_REGEX = Regexp.union(FOLD_FROM.chars)

    # The query's words, folded.
    def self.words(query)
      query.to_s.gsub(FOLD_REGEX, FOLD_MAP).split
    end

    # A SQL condition that's true when `word` (already folded) starts a word of the text in `expression`.
    # The text is folded and given a space in front, so every word in it follows a space. The fold
    # strings are bound rather than inlined because they contain "?", which `where` would take for a
    # placeholder.
    def self.condition(expression, word)
      ActiveRecord::Base.sanitize_sql_array(["(' ' || translate(#{expression}, ?, ?)) ILIKE ?",
        FOLD_FROM, FOLD_TO, "% #{ActiveRecord::Base.sanitize_sql_like(word)}%"])
    end
  end
end
