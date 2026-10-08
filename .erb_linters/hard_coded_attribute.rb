# frozen_string_literal: true

require "better_html"
require "better_html/tree/tag"

module ERBLint
  module Linters
    # Flags literal text in user-visible HTML attributes, e.g. aria-label="Close". The built-in
    # HardCodedString linter only checks text between tags. Values built with ERB
    # (aria-label="<%= t(".close") %>") are fine.
    class HardCodedAttribute < Linter
      include LinterRegistry

      ATTRIBUTES = %w[aria-label alt title placeholder].freeze

      def run(processed_source)
        processed_source.parser.nodes_with_type(:tag).each do |tag_node|
          tag = BetterHtml::Tree::Tag.from_node(tag_node)
          next if tag.closing?

          ATTRIBUTES.each do |name|
            attribute = tag.attributes[name]
            next if attribute&.value_node.nil? || contains_erb?(attribute.value_node)
            next unless attribute.value.match?(/[[:alpha:]]/)
            add_offense(attribute.loc, "Hard-coded #{name}. Move it to a locale file and use `t`.")
          end
        end
      end

      private

      def contains_erb?(node)
        node.to_a.any? { |child| child.is_a?(BetterHtml::AST::Node) && (child.type == :erb || contains_erb?(child)) }
      end
    end
  end
end
