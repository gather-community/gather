# frozen_string_literal: true

module RuboCop
  module Cop
    module Gather
      # Flags string literals that look like user-facing text, which belongs in a locale file instead.
      # See "User-Facing Strings" in CLAUDE.md. "Looks like text" means starting with a capitalized word
      # ("Close", "Privacy policy", "Generated: #{time}"), which CSS classes, keys and format strings don't.
      # Exception messages and log lines are developer-facing, so they're ignored.
      #
      # @example
      #   # bad
      #   link_to("Privacy Policy", path)
      #   "Generated: #{l(time)}"
      #
      #   # good
      #   link_to(t(".privacy_policy"), path)
      #   t(".generated", time: l(time))
      class HardCodedString < Base
        MSG = "Hard-coded user-facing text. Move it to a locale file and use `t`."
        TEXT = /\A\s*[[:upper:]][[:lower:]]+/

        def on_str(node)
          return if node.parent&.dstr_type? # Checked as a whole by on_dstr.
          check(node, node.value)
        end

        def on_dstr(node)
          first = node.children.first
          check(node, first.value) if first&.str_type?
        end

        private

        def check(node, text)
          return unless text.is_a?(String) && TEXT.match?(text)
          return if developer_facing?(node)
          add_offense(node)
        end

        def developer_facing?(node)
          node.each_ancestor(:send).any? do |send|
            %i[raise fail].include?(send.method_name) ||
              exception_new?(send) ||
              send.receiver&.source&.match?(/\A(Rails\.)?logger\z/)
          end
        end

        def exception_new?(send)
          send.method?(:new) && send.receiver&.const_type? && send.receiver.const_name.end_with?("Error")
        end
      end
    end
  end
end
