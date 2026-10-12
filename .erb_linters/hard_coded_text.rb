# frozen_string_literal: true

require "erb_lint/linters/hard_coded_string"

module ERBLint
  module Linters
    # The built-in HardCodedString linter, except text with no letters in it (HTML entities, punctuation,
    # separators like "--------") is ignored, since there's nothing to translate.
    class HardCodedText < HardCodedString
      include LinterRegistry

      private

      def check_string?(str)
        super && str.gsub(/&[#\w]+;/, "").match?(/[[:alpha:]]/)
      end
    end
  end
end
