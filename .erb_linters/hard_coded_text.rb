# frozen_string_literal: true

require "erb_lint/linters/hard_coded_string"

module ERBLint
  module Linters
    # The built-in HardCodedString linter, except:
    # - text with no letters in it (HTML entities, punctuation, separators like "--------") is ignored,
    #   since there's nothing to translate.
    # - JS inside a `javascript_tag do` block is ignored, just like the built-in linter ignores <script>.
    class HardCodedText < HardCodedString
      include LinterRegistry

      def run(processed_source)
        processed_source.ast.descendants(:text).each do |text_node|
          next if non_text_tag?(processed_source, text_node)

          strings_outside_javascript_tags(text_node).each do |offended_string|
            offended_string.split("\n").each do |str|
              next unless check_string?(str)

              source_range = processed_source.to_source_range(find_range(text_node, str))
              add_offense(source_range, message(source_range.source))
            end
          end
        end
      end

      private

      def check_string?(str)
        super && str.gsub(/&[#\w]+;/, "").match?(/[[:alpha:]]/)
      end

      # Block depth is tracked so that an `if ... end` inside the JS doesn't end the block early.
      def strings_outside_javascript_tags(text_node)
        depth = 0
        text_node.to_a.each_with_object([]) do |child, strings|
          if child.is_a?(String)
            strings << child if depth.zero? && relevant_node(child)
          elsif child.type == :erb
            code = child.to_a.find { |c| c.respond_to?(:type) && c.type == :code }&.to_a&.first.to_s
            if depth.zero?
              depth = 1 if code.match?(/\bjavascript_tag\b.*\bdo\b/)
            elsif code.match?(/\bdo\b(\s*\|[^|]*\|)?\s*\z|\A\s*(if|unless|case|while)\b/)
              depth += 1
            elsif code.strip == "end"
              depth -= 1
            end
          end
        end
      end
    end
  end
end
