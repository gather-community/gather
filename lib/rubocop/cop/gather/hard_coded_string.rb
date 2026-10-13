# frozen_string_literal: true

module RuboCop
  module Cop
    module Gather
      # Flags string literals that look like user-facing text, which belongs in a locale file instead.
      # See "User-Facing Strings" in CLAUDE.md. "Looks like text" means starting with a capitalized word
      # ("Close", "Privacy policy", "Generated: #{time}"), which CSS classes, keys and format strings don't.
      # Exception messages, log and audit lines, regexps and class names ("Meals::Meal") are
      # developer-facing, so they're ignored. So are strings used as keys or compared against
      # (headers["Content-Type"], kind == "User", {"User" => "photo"}), which are identifiers, not text.
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
        # A namespaced constant name, e.g. "Work::JobReminderDelivery".
        CLASS_NAME = /\A[[:upper:]]\w*(::[[:upper:]]\w*)+\z/
        # The start of a class name built by interpolation, e.g. "Calendars::Rules::".
        NAMESPACE_PREFIX = /\A[[:upper:]]\w*(::[[:upper:]]\w*)*::\z/
        KEY_METHODS = %i[[] dig key? header == != eql?].freeze

        def on_str(node)
          return if node.parent&.dstr_type? # Checked as a whole by on_dstr.
          check(node, node.value)
        end

        def on_dstr(node)
          first = node.children.first
          return unless first&.str_type?
          return if NAMESPACE_PREFIX.match?(first.value) # e.g. "CustomFields::Fields::#{type}Field"
          check(node, first.value)
        end

        private

        def check(node, text)
          return unless text.is_a?(String) && TEXT.match?(text)
          return if CLASS_NAME.match?(text) || node.each_ancestor(:regexp).any? || constantized?(node)
          return if developer_facing?(node) || class_name_option?(node) || identifier?(node)
          add_offense(node)
        end

        def developer_facing?(node)
          node.each_ancestor(:send).any? do |send|
            %i[raise fail log].include?(send.method_name) ||
              send.receiver&.source == "EventLog" ||
              exception_new?(send) ||
              send.receiver&.source&.match?(/\A(Rails\.)?logger\z/)
          end
        end

        # Part of a string that's turned into a class, e.g. (name.classify << "Lens").constantize.
        def constantized?(node)
          node.each_ancestor(:send).any? { |send| send.method?(:constantize) }
        end

        # A lookup key, a comparison operand, or a hash key: headers["Vary"], type == "User", {"User" => 1}.
        def identifier?(node)
          parent = node.parent
          return true if parent&.pair_type? && parent.key.equal?(node)
          return false unless parent&.send_type?
          args = parent.arguments
          case parent.method_name
          when :[]= then args[0...-1].any? { |a| a.equal?(node) } # Not the assigned value.
          when :fetch then args.first.equal?(node) # Not the default.
          else KEY_METHODS.include?(parent.method_name)
          end
        end

        # e.g. belongs_to :guardian, class_name: "User"
        def class_name_option?(node)
          node.parent&.pair_type? && node.parent.value.equal?(node) &&
            node.parent.key.sym_type? && node.parent.key.value == :class_name
        end

        def exception_new?(send)
          send.method?(:new) && send.receiver&.const_type? && send.receiver.const_name.end_with?("Error")
        end
      end
    end
  end
end
